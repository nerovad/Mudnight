require "securerandom"
require "bigdecimal"

# Ported from backend/src/controllers/mediaController.ts (+ the multer,
# checkUploadCapacity and handleUploadError middleware on its upload route).
#
# Upload pipeline, in Express order:
#   authenticateToken -> checkUploadCapacity -> multer.single("file")
#   -> uploadMedia -> handleUploadError
#
# Rails parses the multipart body when the controller first touches params
# (ActionController::Instrumentation does that before any before_action), so
# `process_action` below runs the capacity check — from Content-Length alone —
# and decides whether the body should be parsed at all BEFORE that happens.
# When it is parsed, Rack writes the file part into MEDIA_ROOT/.uploads (same
# filesystem as the channel dirs, so the final move is a rename), like multer's
# diskStorage did.
class Api::MediaController < ApplicationController
  include ChannelOwnerAuth

  # Hard ceiling on a single master. Tune per deployment via env.
  MAX_UPLOAD_BYTES = Js.number(Js.truthy?(ENV["MEDIA_MAX_UPLOAD_BYTES"]) ? ENV["MEDIA_MAX_UPLOAD_BYTES"] : 16 * 1024 * 1024 * 1024)

  # Bytes to leave free on the media filesystem no matter what.
  DISK_RESERVE_BYTES = Js.number(Js.truthy?(ENV["MEDIA_DISK_RESERVE_BYTES"]) ? ENV["MEDIA_DISK_RESERVE_BYTES"] : 2 * 1024 * 1024 * 1024)

  # Conform writes the house-format file while the raw master is still on
  # disk, so peak usage is master + output; budget a full second copy.
  PEAK_DISK_MULTIPLIER = 2

  FORBIDDEN = "Only the channel owner can manage media".freeze

  before_action :authenticate_token!
  before_action :reject_upload!, only: :create

  # POST /api/channels/:slug/media   (multipart: field "file", plus "title")
  def create
    file = params[:file]
    file = nil unless file.is_a?(ActionDispatch::Http::UploadedFile)

    uid = auth_user_id_or_401
    unless uid
      discard_upload_files # (Express leaked the temp file here until the sweep)
      return
    end

    unless file
      render json: { error: "No file uploaded (expected multipart field 'file')" }, status: :bad_request
      return
    end

    tmp_path = file.tempfile.path
    begin
      file.tempfile.close unless file.tempfile.closed?
    rescue IOError
    end
    cleanup_tmp = -> { safe_unlink(tmp_path) }

    begin
      channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
      unless channel
        cleanup_tmp.call
        return
      end

      original_name = file.original_filename
      body_title = body["title"]
      body_title = "" if body_title.nil?
      title_src =
        if Js.truthy?(body_title) then body_title
        elsif Js.truthy?(original_name) then original_name
        else "Untitled"
        end
      title = js_string(title_src)[0, 200]
      uuid = SecureRandom.uuid

      # Move the temp upload into the channel's raw dir.
      dest = MediaStorage.raw_path(channel["id"], uuid, Js.truthy?(original_name) ? original_name : "master")
      MediaStorage.ensure_dir(File.dirname(dest))
      begin
        File.rename(tmp_path, dest)
      rescue SystemCallError
        # rename across filesystems can EXDEV — fall back to copy+unlink
        FileUtils.cp(tmp_path, dest)
        safe_unlink(tmp_path)
      end

      # Pending row. duration_ms is filled in by the conform worker (NOT NULL,
      # so 0 as a placeholder until 'ready').
      media = Db.query(
        "INSERT INTO channel_media
         (channel_id, title, storage_path, duration_ms, source_kind, original_name, conform_status)
       VALUES ($1, $2, $3, 0, 'hosted', $4, 'pending')
       RETURNING id, title, duration_ms, conform_status, created_at",
        [channel["id"], title, "raw/#{uuid}", Js.truthy?(original_name) ? original_name : nil]
      ).rows[0]

      # Fire-and-forget conform; the row flips to ready/failed when it finishes.
      ConformMediaJob.perform_later(media["id"], channel["id"], uuid, dest)

      render json: { media: media }, status: :accepted
    rescue StandardError => e
      cleanup_tmp.call
      Rails.logger.error("uploadMedia error: #{e.class}: #{e.message}")
      render json: { error: "Upload failed" }, status: :internal_server_error
    end
  end

  # GET /api/channels/:slug/media — the channel's media catalogue (owner only).
  def index
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    rows = Db.query(
      "SELECT id, title, duration_ms, source_kind, conform_status, original_name, created_at
         FROM channel_media
        WHERE channel_id = $1
        ORDER BY created_at DESC",
      [channel["id"]]
    ).rows
    render json: { media: rows }
  rescue StandardError => e
    Rails.logger.error("listMedia error: #{e.class}: #{e.message}")
    render json: { error: "Failed to list media" }, status: :internal_server_error
  end

  # DELETE /api/channels/:slug/media/:id — remove a media item and its file.
  def destroy
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    media_id = Js.number(params[:id])
    rows = Db.query(
      "DELETE FROM channel_media WHERE id = $1 AND channel_id = $2
       RETURNING storage_path",
      [media_id, channel["id"]]
    ).rows
    if rows.empty?
      render json: { error: "Media not found" }, status: :not_found
      return
    end
    # Best-effort file cleanup. (For a still-pending row storage_path is
    # "raw/<uuid>", which never matches the real raw file — same as Express.)
    safe_unlink(File.join(MediaStorage.channel_root(channel["id"]), rows[0]["storage_path"].to_s))
    head :no_content
  rescue StandardError => e
    Rails.logger.error("deleteMedia error: #{e.class}: #{e.message}")
    render json: { error: "Failed to delete media" }, status: :internal_server_error
  end

  # PATCH /api/channels/:slug/media/:id  (owner only) — rename; bumps schedule_rev.
  def update
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    media_id = Js.number(params[:id])
    title = body["title"].is_a?(String) ? js_trim(body["title"]) : ""
    if title.empty?
      render json: { error: "title is required" }, status: :bad_request
      return
    end

    rows = Db.query(
      "UPDATE channel_media SET title = $3
        WHERE id = $1 AND channel_id = $2
        RETURNING id, title, duration_ms, conform_status, original_name",
      [media_id, channel["id"], title]
    ).rows
    if rows.empty?
      render json: { error: "Media not found" }, status: :not_found
      return
    end
    Db.query("UPDATE channels SET schedule_rev = now() WHERE id = $1", [channel["id"]])
    render json: { media: rows[0] }
  rescue StandardError => e
    Rails.logger.error("renameMedia error: #{e.class}: #{e.message}")
    render json: { error: "Failed to rename media" }, status: :internal_server_error
  end

  private

  def process_action(*)
    prepare_upload! if action_name == "create"
    super
  end

  # Runs before Rails reads the body. Mirrors the Express ordering:
  #  - a request authenticateToken would reject is never parsed (multer never ran);
  #  - checkUploadCapacity rejects from Content-Length without reading the body;
  #  - otherwise parse now, with multer-equivalent error mapping.
  def prepare_upload!
    unless token_acceptable?
      skip_body!
      return
    end

    if (rejection = capacity_rejection)
      @upload_rejection = rejection
      skip_body!
      return
    end

    @upload_files = []
    files = @upload_files
    request.env[Rack::RACK_MULTIPART_TEMPFILE_FACTORY] = lambda do |_filename, _content_type|
      dir = MediaStorage.upload_tmp_dir
      MediaStorage.ensure_dir(dir)
      path = File.join(dir, "up_#{(Time.now.to_f * 1000).to_i}_#{SecureRandom.hex(6)}")
      f = File.open(path, "wb+")
      files << f
      f
    end

    begin
      request.request_parameters
    rescue Errno::ENOSPC
      @upload_rejection = [507, { error: "The server ran out of disk space during the upload." }]
    rescue Rack::Multipart::Error, ActionController::BadRequest, EOFError => e
      @upload_rejection =
        if e.message.include?("exceeds limit")
          [413, { error: "File is too large. The limit is #{gb(MAX_UPLOAD_BYTES)} GB." }]
        else
          [400, { error: "Upload rejected: #{e.message}" }]
        end
    end

    if @upload_rejection
      discard_upload_files
      skip_body!
      return
    end

    # multer.single("file") semantics checked post-parse.
    file = request.request_parameters["file"]
    unexpected = request.request_parameters.any? do |k, v|
      k == "file" ? !(v.is_a?(ActionDispatch::Http::UploadedFile) || !contains_upload?(v)) : contains_upload?(v)
    end
    if unexpected
      @upload_rejection = [400, { error: "Upload rejected: Unexpected field" }]
    elsif file.is_a?(ActionDispatch::Http::UploadedFile) && MAX_UPLOAD_BYTES && file.size > MAX_UPLOAD_BYTES
      @upload_rejection = [413, { error: "File is too large. The limit is #{gb(MAX_UPLOAD_BYTES)} GB." }]
    end
    discard_upload_files if @upload_rejection
  end

  # Would ApplicationController#authenticate_token! accept the token?
  def token_acceptable?
    token = request.authorization.to_s.split(" ")[1]
    return false if token.blank?
    JsonWebToken.decode(token)
    true
  rescue JWT::DecodeError
    false
  end

  # checkUploadCapacity: [status, body] or nil to proceed.
  def capacity_rejection
    declared = Js.number(request.headers["Content-Length"].presence || 0)
    return nil unless finite?(declared) && declared > 0 # chunked / unknown length

    if MAX_UPLOAD_BYTES && declared > MAX_UPLOAD_BYTES
      return [413, { error: "File is too large. The limit is #{gb(MAX_UPLOAD_BYTES)} GB and this file is #{gb(declared)} GB." }]
    end

    free = MediaStorage.free_bytes_at_media_root
    return nil if free.nil? # couldn't measure — don't block

    needed = declared * PEAK_DISK_MULTIPLIER + DISK_RESERVE_BYTES.to_i
    if needed > free
      affordable = [0, (free - DISK_RESERVE_BYTES.to_i) / PEAK_DISK_MULTIPLIER.to_f].max
      return [507, {
        error: "Not enough space to process this file. A #{gb(declared)} GB master needs about " \
               "#{gb(declared * PEAK_DISK_MULTIPLIER)} GB while it converts, and only #{gb(free)} GB is free. " \
               "The largest file this server can take right now is about #{gb(affordable)} GB."
      }]
    end
    nil
  end

  def reject_upload!
    return unless @upload_rejection

    status, payload = @upload_rejection
    render json: payload, status: status
  end

  def skip_body!
    request.request_parameters = {}
  end

  def contains_upload?(v)
    case v
    when ActionDispatch::Http::UploadedFile then true
    when Hash then v.values.any? { |x| contains_upload?(x) }
    when Array then v.any? { |x| contains_upload?(x) }
    else false
    end
  end

  def discard_upload_files
    (@upload_files || []).each do |f|
      begin
        f.close unless f.closed?
      rescue IOError
      end
      safe_unlink(f.path)
    end
  end

  def safe_unlink(path)
    File.unlink(path) if path
  rescue SystemCallError
  end

  # (bytes / 1024 / 1024 / 1024).toFixed(1) — toFixed rounds the exact
  # binary value half-up, which printf's round-half-even does not.
  def gb(bytes)
    x = bytes.to_f / 1024 / 1024 / 1024
    BigDecimal(x.to_r, 40).round(1, BigDecimal::ROUND_HALF_UP).to_s("F")
  end

  def js_string(v)
    case v
    when String then v
    when Array then v.map { |x| x.nil? ? "" : js_string(x) }.join(",")
    else v.to_s
    end
  end
end
