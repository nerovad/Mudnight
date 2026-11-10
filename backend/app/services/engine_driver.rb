# How the supervisor actually starts/stops a channel's playout engine
# (ported from backend/src/services/engineDriver.ts).
#
# Behind an interface because the concrete mechanism depends on how ffplayout
# is deployed; the safe default does nothing but log. Swap the driver via
# PLAYOUT_ENGINE_DRIVER ("logging" | "ffplayout-api" | "ffplayout-control").
module EngineDriver
  # id: channels.id (String, bigint as decoded by Db), slug,
  # ffplayout_channel_id: the integer channel id inside ffplayout.
  Channel = Struct.new(:id, :slug, :ffplayout_channel_id, keyword_init: true)

  # Default: no side effects, just a log line. Safe to run without ffplayout.
  class LoggingEngineDriver
    def start(channel)
      Rails.logger.info("[playout] would START engine for channel #{channel.slug} (id #{channel.id})")
    end

    def stop(channel)
      Rails.logger.info("[playout] would STOP engine for channel #{channel.slug} (id #{channel.id})")
    end
  end

  # Drives a running ffplayout via POST {base}/api/control/{id}/process with a
  # static bearer token (FFPLAYOUT_TOKEN). Logs failures rather than raising.
  class FfplayoutControlDriver
    def initialize(base_url, token)
      @base_url = base_url
      @token = token
    end

    def start(channel) = command(channel, "start")
    def stop(channel) = command(channel, "stop")

    private

    def command(channel, command)
      url = "#{@base_url.sub(%r{/\z}, '')}/api/control/#{channel.ffplayout_channel_id}/process"
      begin
        res = FfplayoutClient.http("POST", url,
          headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" },
          body: JSON.generate({ command: command }))
        unless res.ok?
          Rails.logger.error("[playout] ffplayout #{command} for #{channel.slug} failed: #{res.status}")
        end
      rescue StandardError => e
        Rails.logger.error("[playout] ffplayout #{command} for #{channel.slug} errored: #{e.class}: #{e.message}")
      end
      nil
    end
  end

  # Full push-based driver (the one Phase 5 integration proved out). `start`
  # configures the channel's stream output to push RTMP at the tower,
  # generates today's (UTC) playlist with ABSOLUTE sources, pushes it, then
  # starts playout. `stop` just stops the process.
  class FfplayoutApiDriver
    def initialize(client, pool, rtmp_base:, task_path:)
      @client = client
      @pool = pool
      @rtmp_base = rtmp_base
      @task_path = task_path
    end

    def start(channel)
      ff = channel.ffplayout_channel_id

      ch_rows = @pool.query(
        "SELECT stream_key, COALESCE(display_name, name) AS label
         FROM channels WHERE id = $1 LIMIT 1",
        [channel.id]
      ).rows
      raise "channel #{channel.id} not found" if ch_rows.empty?
      stream_key = ch_rows[0]["stream_key"]
      label = ch_rows[0]["label"]

      segs = @pool.query(
        "SELECT m.storage_path, m.title, s.in_ms, s.out_ms,
              m.duration_ms AS media_duration_ms, s.category
         FROM channel_segments s
         JOIN channel_media m ON m.id = s.media_id
        WHERE s.channel_id = $1 AND m.conform_status = 'ready'
        ORDER BY s.position ASC",
        [channel.id]
      ).rows

      storage_root = "#{MediaStorage::MEDIA_ROOT}/#{channel.id}"
      # JS template literal renders a NULL stream_key as "null"
      stream_url = "#{@rtmp_base.sub(%r{/\z}, '')}/#{stream_key.nil? ? 'null' : stream_key}"
      date = Time.now.utc.strftime("%Y-%m-%d") # UTC broadcast day

      @client.configure_stream_output(ff,
        stream_url: stream_url,
        width: MediaStorage::HOUSE_FORMAT[:width],
        height: MediaStorage::HOUSE_FORMAT[:height],
        fps: MediaStorage::HOUSE_FORMAT[:fps],
        task_path: @task_path)

      playlist = Playlist.build_day_playlist(Js.truthy?(label) ? label : "Channel", date, segs, 86400, storage_root)
      @client.push_playlist(ff, playlist)
      @client.control(ff, "start")
    end

    def stop(channel)
      @client.control(channel.ffplayout_channel_id, "stop")
    end
  end

  module_function

  # Pick a driver from env. Defaults to logging (safe, no-op side effects).
  # `pool` is the DB handle (the Db module); without it ffplayout-api falls back.
  def from_env(pool = nil)
    kind = (Js.truthy?(ENV["PLAYOUT_ENGINE_DRIVER"]) ? ENV["PLAYOUT_ENGINE_DRIVER"] : "logging").downcase
    if kind == "ffplayout-api"
      base = ENV["FFPLAYOUT_BASE_URL"].to_s
      user = ENV["FFPLAYOUT_USER"].to_s
      pass = ENV["FFPLAYOUT_PASSWORD"].to_s
      rtmp_base = ENV["RTMP_INGEST_URL"].to_s
      task_path = ENV["FFPLAYOUT_TASK_PATH"].to_s
      if base.empty? || user.empty? || pass.empty? || rtmp_base.empty? || task_path.empty? || pool.nil?
        Rails.logger.warn("[playout] ffplayout-api driver selected but FFPLAYOUT_BASE_URL/USER/PASSWORD, RTMP_INGEST_URL, FFPLAYOUT_TASK_PATH or DB pool missing — using logging driver")
        return LoggingEngineDriver.new
      end
      return FfplayoutApiDriver.new(FfplayoutClient.new(base, user, pass), pool, rtmp_base: rtmp_base, task_path: task_path)
    end
    if kind == "ffplayout-control"
      base = ENV["FFPLAYOUT_BASE_URL"].to_s
      token = ENV["FFPLAYOUT_TOKEN"].to_s
      if base.empty? || token.empty?
        Rails.logger.warn("[playout] ffplayout-control driver selected but FFPLAYOUT_BASE_URL/TOKEN unset — using logging driver")
        return LoggingEngineDriver.new
      end
      return FfplayoutControlDriver.new(base, token)
    end
    LoggingEngineDriver.new
  end
end
