require "securerandom"

# Ported from backend/src/controllers/playoutController.ts.
#   provision / show_config (getPlayoutConfig) / tune  — under /api/channels/:slug/playout
#   asrun / playlist                                   — /api/playout (ffplayout-facing)
class Api::PlayoutController < ApplicationController
  include ChannelOwnerAuth

  # Where the public API and RTMP tower live, for the engine config we emit.
  PUBLIC_BASE_URL = (Js.truthy?(ENV["PUBLIC_BASE_URL"]) ? ENV["PUBLIC_BASE_URL"] : "https://cinezoo.tv").sub(%r{/\z}, "")
  RTMP_INGEST_URL = (Js.truthy?(ENV["RTMP_INGEST_URL"]) ? ENV["RTMP_INGEST_URL"] : "rtmp://cinezoo.tv:1935/live").sub(%r{/\z}, "")

  DATE_FILE = /\A(\d{4}-\d{2}-\d{2})\.json\z/

  before_action :authenticate_token!, only: %i[provision show_config]

  # POST /api/channels/:slug/playout/provision   (owner only)
  def provision
    uid = auth_user_id_or_401
    return unless uid

    rows = Db.query(
      "SELECT id, owner_id, stream_key, playout_token FROM channels WHERE slug = $1 LIMIT 1",
      [params[:slug]]
    ).rows
    return render(json: { error: "Channel not found" }, status: :not_found) if rows.empty?
    ch = rows[0]
    return render(json: { error: "Only the channel owner can provision playout" }, status: :forbidden) unless ch["owner_id"] == uid

    token = Js.truthy?(ch["playout_token"]) ? ch["playout_token"] : SecureRandom.hex(24)
    upd = Db.query(
      "UPDATE channels
          SET playout_token = $2, playout_mode = 'scheduled'
        WHERE id = $1
        RETURNING id, stream_key, playout_token",
      [ch["id"], token]
    )
    render json: { config: build_playout_config(upd.rows[0]) }
  rescue StandardError => e
    Rails.logger.error("provisionPlayout error: #{e.class}: #{e.message}")
    render json: { error: "Failed to provision playout" }, status: :internal_server_error
  end

  # GET /api/channels/:slug/playout/config   (owner only)
  def show_config
    uid = auth_user_id_or_401
    return unless uid

    rows = Db.query(
      "SELECT id, owner_id, stream_key, playout_token, playout_mode FROM channels WHERE slug = $1 LIMIT 1",
      [params[:slug]]
    ).rows
    return render(json: { error: "Channel not found" }, status: :not_found) if rows.empty?
    ch = rows[0]
    return render(json: { error: "Only the channel owner can view playout config" }, status: :forbidden) unless ch["owner_id"] == uid
    return render(json: { error: "Channel is not provisioned for playout" }, status: :conflict) unless Js.truthy?(ch["playout_token"])

    render json: { config: build_playout_config(ch), playout_mode: ch["playout_mode"] }
  rescue StandardError => e
    Rails.logger.error("getPlayoutConfig error: #{e.class}: #{e.message}")
    render json: { error: "Failed to read playout config" }, status: :internal_server_error
  end

  # POST /api/channels/:slug/playout/tune   (public — viewers are anonymous)
  # Always 202, whatever the slug; the supervisor start runs in the background.
  def tune
    slug = js_trim(params[:slug].to_s)
    OnDemandPlayout.instance.tune_in(slug)
    render json: { ok: true }, status: :accepted
  end

  # GET /api/playout/pl/:token/:year/:month/:date   (:date = "YYYY-MM-DD.json")
  # The URL ffplayout is pointed at; the token identifies and authorizes.
  def playlist
    token = js_trim(params[:token].to_s)
    date_match = DATE_FILE.match(params[:date].to_s)
    return send_text("bad request", 400) if token.empty? || date_match.nil?
    date = date_match[1]

    begin
      chan = Db.query(
        "SELECT id, COALESCE(display_name, name) AS label, schedule_rev
         FROM channels WHERE playout_token = $1 LIMIT 1",
        [token]
      )
      return send_text("unknown channel", 404) if chan.row_count == 0
      channel = chan.rows[0]

      # Last-Modified / If-Modified-Since: schedule_rev bumps on any segment mutation.
      last_modified = channel["schedule_rev"] || Time.at(0).utc
      ims = request.headers["If-Modified-Since"]
      if Js.truthy?(ims)
        since = parse_js_date(ims)
        if since && since.to_r >= last_modified.to_i # Last-Modified truncated to the second, like the TS
          head :not_modified
          return
        end
      end

      seg = Db.query(
        "SELECT m.storage_path, m.title, s.in_ms, s.out_ms,
              m.duration_ms AS media_duration_ms, s.category
         FROM channel_segments s
         JOIN channel_media m ON m.id = s.media_id
        WHERE s.channel_id = $1 AND m.conform_status = 'ready'
        ORDER BY s.position ASC",
        [channel["id"]]
      )

      pl = Playlist.build_day_playlist(Js.truthy?(channel["label"]) ? channel["label"] : "Channel", date, seg.rows)

      response.headers["Last-Modified"] = last_modified.utc.httpdate
      response.headers["Cache-Control"] = "no-cache"
      render json: pl
    rescue StandardError => e
      Rails.logger.error("getPlaylist error: #{e.class}: #{e.message}")
      send_text("playlist error", 500)
    end
  end

  # POST /api/playout/asrun   (ffplayout task-script hook, auth: X-Stream-Key)
  # Records what actually aired. Lenient: record what we can, answer 204.
  def asrun
    stream_key = js_trim(request.headers["X-Stream-Key"].to_s)
    return send_text("missing stream key", 401) if stream_key.empty?

    payload = body
    media = payload["media"].nil? ? {} : payload["media"]
    media = {} unless media.is_a?(Hash) # property access on a non-object => undefined
    source = media["source"].is_a?(String) ? media["source"] : ""
    return send_text("missing media.source", 400) if source.empty?

    begin
      chan = Db.query("SELECT id FROM channels WHERE stream_key = $1 LIMIT 1", [stream_key])
      return send_text("invalid stream key", 403) if chan.row_count == 0
      channel_id = chan.rows[0]["id"]

      # Playing time is out - in (NOT `duration`, which is the full asset length).
      in_sec = js_or_zero(media["in"])
      out_sec = js_or_zero(media["out"])
      duration_ms = out_sec > in_sec ? ((out_sec - in_sec) * 1000 + 0.5).floor : nil

      is_ingest = payload["ingest"] == true
      title = media["title"].is_a?(String) ? media["title"] : nil

      # Best-effort attribution back to a scheduled segment, matching either
      # the reported (absolute) source or its basename.
      source_basename = source.split("/", -1).last
      source_basename = source unless Js.truthy?(source_basename)
      seg = Db.query(
        "SELECT s.id
         FROM channel_segments s
         JOIN channel_media m ON m.id = s.media_id
        WHERE s.channel_id = $1
          AND (m.storage_path = $2 OR m.storage_path = $3)
        ORDER BY s.position
        LIMIT 1",
        [channel_id, source, source_basename]
      )
      segment_id = seg.row_count.positive? ? seg.rows[0]["id"] : nil

      Db.query(
        "INSERT INTO channel_asrun
         (channel_id, segment_id, source, title, started_at, duration_ms, is_ingest, raw)
       VALUES ($1, $2, $3, $4, now(), $5, $6, $7)",
        [channel_id, segment_id, source, title, duration_ms, is_ingest, js_json(payload)]
      )

      head :no_content
    rescue StandardError => e
      Rails.logger.error("recordAsRun error: #{e.class}: #{e.message}")
      send_text("as-run error", 500)
    end
  end

  private

  # Shape the ffplayout-facing config for a provisioned channel.
  def build_playout_config(channel)
    {
      channel_id: channel["id"],
      playout_mode: "scheduled",
      # ffplayout `playlists` config -> it fetches <base>/YYYY/MM/YYYY-MM-DD.json
      playlist_url: "#{PUBLIC_BASE_URL}/api/playout/pl/#{js_str(channel['playout_token'])}",
      # ffplayout stream output target (its push lands in Cinezoo's nginx-rtmp)
      rtmp_output: "#{RTMP_INGEST_URL}/#{js_str(channel['stream_key'])}",
      # ffplayout storage root — where conformed media for this channel lives
      media_storage_root: "#{MediaStorage::MEDIA_ROOT}/#{channel['id']}",
      # as-run task-script target + the secret it authenticates with
      asrun_url: "#{PUBLIC_BASE_URL}/api/playout/asrun",
      stream_key: channel["stream_key"]
    }
  end

  # `${x}` in a JS template literal: null renders as "null".
  def js_str(v)
    v.nil? ? "null" : v.to_s
  end

  # Number(v) || 0
  def js_or_zero(v)
    n = js_to_number(v)
    Js.truthy?(n) ? n : 0
  end

  # new Date(str) for the header formats a client may send; nil = Invalid Date.
  def parse_js_date(str)
    Time.httpdate(str)
  rescue ArgumentError
    begin
      Time.rfc2822(str)
    rescue ArgumentError
      begin
        Time.iso8601(str)
      rescue ArgumentError
        nil
      end
    end
  end

  # node-postgres JSON.stringify()s object params; JSON.parse had already
  # collapsed integral floats (252.0 -> 252), so mirror that.
  def js_json(value)
    normalize = lambda do |v|
      case v
      when Hash then v.to_h { |k, x| [k.to_s, normalize.call(x)] }
      when Array then v.map { |x| normalize.call(x) }
      when Float then v.finite? && v == v.floor && v.abs < 1e21 ? v.to_i : v
      else v
      end
    end
    JSON.generate(normalize.call(value))
  end
end
