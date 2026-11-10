require "securerandom"

# Ported from backend/src/controllers/segmentController.ts — the ordered
# program list that becomes a scheduled channel's playlist.
class Api::SegmentsController < ApplicationController
  include ChannelOwnerAuth

  FORBIDDEN = "Only the channel owner can manage the schedule".freeze

  before_action :authenticate_token!

  # GET /api/channels/:slug/segments
  def index
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    rows = Db.query(
      "SELECT s.id, s.media_id, s.position, s.in_ms, s.out_ms, s.category,
              s.contribution_id,
              (s.out_ms - s.in_ms) AS playing_ms,
              m.title, m.duration_ms AS media_duration_ms, m.conform_status
         FROM channel_segments s
         JOIN channel_media m ON m.id = s.media_id
        WHERE s.channel_id = $1
        ORDER BY s.position ASC",
      [channel["id"]]
    ).rows
    render json: { segments: rows }
  rescue StandardError => e
    Rails.logger.error("listSegments error: #{e.class}: #{e.message}")
    render json: { error: "Failed to list segments" }, status: :internal_server_error
  end

  # POST /api/channels/:slug/segments   { media_id, in_ms?, out_ms?, category? }
  def create
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    media_id = js_to_number(body["media_id"], missing: !body.key?("media_id"))
    unless finite?(media_id)
      render json: { error: "media_id is required" }, status: :bad_request
      return
    end
    media_id = js_param(media_id)

    m = Db.query(
      "SELECT id, duration_ms, conform_status
         FROM channel_media WHERE id = $1 AND channel_id = $2 LIMIT 1",
      [media_id, channel["id"]]
    )
    if m.row_count == 0
      render json: { error: "Media not found on this channel" }, status: :not_found
      return
    end
    if m.rows[0]["conform_status"] != "ready"
      render json: { error: "Media is not ready (status: #{m.rows[0]['conform_status']})" }, status: :conflict
      return
    end

    full_ms = Js.number(m.rows[0]["duration_ms"])
    in_ms = clamp_int("in_ms", 0, 0, full_ms)
    out_ms = clamp_int("out_ms", full_ms, in_ms + 1, full_ms)
    category = body["category"].is_a?(String) ? body["category"] : nil

    pos = Db.query(
      "SELECT COALESCE(MAX(position), 0) + 100 AS next FROM channel_segments WHERE channel_id = $1",
      [channel["id"]]
    )

    ins = Db.query(
      "INSERT INTO channel_segments (channel_id, media_id, position, in_ms, out_ms, category)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, media_id, position, in_ms, out_ms, category, (out_ms - in_ms) AS playing_ms",
      [channel["id"], media_id, pos.rows[0]["next"], in_ms, out_ms, category]
    )

    # Auto-provision: building a loop turns this into a scheduled playout
    # channel. Idempotent — the token is minted once and kept.
    Db.query(
      "UPDATE channels
          SET playout_mode = 'scheduled',
              playout_token = COALESCE(playout_token, $2)
        WHERE id = $1",
      [channel["id"], SecureRandom.hex(24)]
    )

    bump_schedule_rev(channel["id"])
    render json: { segment: ins.rows[0] }, status: :created
  rescue StandardError => e
    Rails.logger.error("addSegment error: #{e.class}: #{e.message}")
    render json: { error: "Failed to add segment" }, status: :internal_server_error
  end

  # PATCH /api/channels/:slug/segments/:id   { in_ms?, out_ms?, category? }
  def update
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    seg_id = Js.number(params[:id])

    cur = Db.query(
      "SELECT s.id, s.in_ms, s.out_ms, m.duration_ms
         FROM channel_segments s JOIN channel_media m ON m.id = s.media_id
        WHERE s.id = $1 AND s.channel_id = $2 LIMIT 1",
      [seg_id, channel["id"]]
    )
    if cur.row_count == 0
      render json: { error: "Segment not found" }, status: :not_found
      return
    end
    full_ms = Js.number(cur.rows[0]["duration_ms"])
    in_ms = clamp_int("in_ms", Js.number(cur.rows[0]["in_ms"]), 0, full_ms)
    out_ms = clamp_int("out_ms", Js.number(cur.rows[0]["out_ms"]), in_ms + 1, full_ms)
    # undefined -> keep; any non-string (incl. null) -> null -> COALESCE keeps too
    category = body["category"].is_a?(String) ? body["category"] : nil

    upd = Db.query(
      "UPDATE channel_segments
          SET in_ms = $2, out_ms = $3,
              category = COALESCE($4, category)
        WHERE id = $1
        RETURNING id, media_id, position, in_ms, out_ms, category, (out_ms - in_ms) AS playing_ms",
      [seg_id, in_ms, out_ms, category]
    )
    bump_schedule_rev(channel["id"])
    render json: { segment: upd.rows[0] }
  rescue StandardError => e
    Rails.logger.error("updateSegment error: #{e.class}: #{e.message}")
    render json: { error: "Failed to update segment" }, status: :internal_server_error
  end

  # POST /api/channels/:slug/segments/reorder   { ordered_ids: [id, id, ...] }
  # Rewrites positions to a gapped sequence (100, 200, ...). The unique
  # (channel_id, position) index is NOT deferrable, so rows are first parked
  # at unique negative positions, then assigned finals.
  def reorder
    uid = auth_user_id_or_401
    return unless uid

    ordered_ids =
      if body["ordered_ids"].is_a?(Array)
        body["ordered_ids"].map { |n| js_to_number(n) }.select { |n| finite?(n) }.map { |n| js_param(n) }
      else
        []
      end

    begin
      chan = Db.query("SELECT id, owner_id FROM channels WHERE slug = $1 LIMIT 1", [params[:slug]])
      if chan.row_count == 0
        render json: { error: "Channel not found" }, status: :not_found
        return
      end
      unless chan.rows[0]["owner_id"] == uid
        render json: { error: FORBIDDEN }, status: :forbidden
        return
      end
      channel_id = chan.rows[0]["id"]

      # ordered_ids must be exactly the channel's current segment set.
      existing = Db.query("SELECT id FROM channel_segments WHERE channel_id = $1", [channel_id])
      existing_ids = existing.rows.map { |r| Js.number(r["id"]) }.to_set
      same_set =
        ordered_ids.length == existing_ids.size &&
        ordered_ids.all? { |id| existing_ids.include?(id) } &&
        ordered_ids.uniq.length == ordered_ids.length
      unless same_set
        render json: { error: "ordered_ids must list every segment of this channel exactly once" }, status: :bad_request
        return
      end

      Db.transaction do
        # Phase 1: park all rows at unique negative positions.
        Db.query("UPDATE channel_segments SET position = -position - 1 WHERE channel_id = $1", [channel_id])
        # Phase 2: assign gapped finals in the requested order.
        ordered_ids.each_with_index do |id, i|
          Db.query(
            "UPDATE channel_segments SET position = $1 WHERE id = $2 AND channel_id = $3",
            [(i + 1) * 100, id, channel_id]
          )
        end
        bump_schedule_rev(channel_id)
      end

      rows = Db.query(
        "SELECT s.id, s.media_id, s.position, s.in_ms, s.out_ms, (s.out_ms - s.in_ms) AS playing_ms,
              m.title
         FROM channel_segments s JOIN channel_media m ON m.id = s.media_id
        WHERE s.channel_id = $1 ORDER BY s.position ASC",
        [channel_id]
      ).rows
      render json: { segments: rows }
    rescue StandardError => e
      Rails.logger.error("reorderSegments error: #{e.class}: #{e.message}")
      render json: { error: "Failed to reorder segments" }, status: :internal_server_error
    end
  end

  # DELETE /api/channels/:slug/segments/:id
  def destroy
    uid = auth_user_id_or_401
    return unless uid

    channel = owned_channel_or_403(params[:slug], uid, FORBIDDEN)
    return unless channel

    seg_id = Js.number(params[:id])
    res = Db.query("DELETE FROM channel_segments WHERE id = $1 AND channel_id = $2", [seg_id, channel["id"]])
    if res.row_count == 0
      render json: { error: "Segment not found" }, status: :not_found
      return
    end
    bump_schedule_rev(channel["id"])
    head :no_content
  rescue StandardError => e
    Rails.logger.error("deleteSegment error: #{e.class}: #{e.message}")
    render json: { error: "Failed to delete segment" }, status: :internal_server_error
  end

  private

  # Bump the channel's schedule revision so the playlist's Last-Modified changes.
  def bump_schedule_rev(channel_id)
    Db.query("UPDATE channels SET schedule_rev = now() WHERE id = $1", [channel_id])
  end

  # clampInt(req.body?.[key], dflt, min, max): parse, default, round, clamp.
  def clamp_int(key, dflt, min, max)
    v = body[key]
    n = v.nil? ? dflt : js_to_number(v)
    return dflt unless finite?(n)

    rounded = n.is_a?(Integer) ? n : (n + 0.5).floor # Math.round
    [min, [max, rounded].min].max
  end
end
