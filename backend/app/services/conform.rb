require "open3"

# Conform an uploaded master to house format, probe the RESULT for an
# authoritative duration, and mark the channel_media row ready. Runs in the
# background (ConformMediaJob, ActiveJob :async). On failure the row is marked
# 'failed'; the raw upload is left in place for inspection.
#
# Ported from backend/src/services/conform.ts. Like the Node version this is an
# in-process worker: a restart mid-conform leaves the row 'pending'.
module Conform
  module_function

  # ffprobe a file for its duration in milliseconds (rounded). Raises on failure.
  def probe_duration_ms(file)
    out, err, status = Open3.capture3(
      "ffprobe",
      "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      file
    )
    secs = Js.parse_float(out.strip)
    code = status.exitstatus
    if code == 0 && secs && secs.finite? && secs > 0
      (secs * 1000).round
    else
      raise "ffprobe failed (code #{code.nil? ? 'null' : code}): #{err.strip.presence || 'no duration'}"
    end
  end

  def conform_media(media_id:, channel_id:, uuid:, raw_path:)
    output = MediaStorage.conformed_abs_path(channel_id, uuid)

    begin
      MediaStorage.ensure_dir(MediaStorage.channel_root(channel_id))

      run_ffmpeg(["-i", raw_path, *MediaStorage.house_format_args(output)])

      # Probe the conformed output, NOT the master — re-encoding can shift the
      # duration slightly, and the playlist/guide must match what actually plays.
      duration_ms = probe_duration_ms(output)

      Db.query(
        "UPDATE channel_media
          SET storage_path = $2, duration_ms = $3, conform_status = 'ready'
        WHERE id = $1",
        [media_id, MediaStorage.conformed_rel_path(uuid), duration_ms]
      )

      # House-format copy is the source of truth now; drop the raw master.
      begin
        File.unlink(raw_path)
      rescue SystemCallError
      end
      Rails.logger.info("conform ready: media #{media_id} (#{duration_ms}ms)")
    rescue StandardError => e
      Rails.logger.error("conform failed: media #{media_id}: #{e.message}")
      begin
        Db.query("UPDATE channel_media SET conform_status = 'failed' WHERE id = $1", [media_id])
      rescue StandardError
      end
    end
    nil
  end

  def run_ffmpeg(args)
    _out, err, status = Open3.capture3("ffmpeg", "-hide_banner", "-loglevel", "error", *args)
    return if status.exitstatus == 0

    code = status.exitstatus
    raise(err.strip.presence || "ffmpeg exit #{code.nil? ? 'null' : code}")
  end
end
