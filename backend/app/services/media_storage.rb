require "fileutils"
require "open3"

# Where hosted channel media lives. Playout (ffplayout) reads from this same
# tree, so in production this should be a volume shared with the playout host.
# Layout, per channel:
#
#   <MEDIA_ROOT>/<channelId>/raw/<uuid>_<originalName>   uploaded master (transient)
#   <MEDIA_ROOT>/<channelId>/<uuid>.mp4                  conformed house-format file
#
# channel_media.storage_path stores the path RELATIVE to the per-channel root
# (e.g. "<uuid>.mp4"), which is exactly what a playlist item's `source` needs.
#
# Ported from backend/src/services/mediaStorage.ts. The Express default was
# path.join(__dirname, "../../media") = backend/media, i.e. Rails.root/media.
module MediaStorage
  MEDIA_ROOT = Js.truthy?(ENV["MEDIA_ROOT"]) ? ENV["MEDIA_ROOT"] : Rails.root.join("media").to_s

  # House broadcast format. Conforming every master to ONE profile on ingest is
  # what makes clip-to-clip joins seamless (mixed source codecs/resolutions are
  # what break HLS continuity). Fixed 1280x720 canvas with letterbox/pillarbox,
  # constant GOP with scene-cut detection off, faststart.
  HOUSE_FORMAT = {
    width: 1280,
    height: 720,
    fps: 30,
    gop: 60, # 2s at 30fps
    videoCodec: "libx264",
    preset: "veryfast",
    audioCodec: "aac",
    audioBitrate: "128k",
    audioRate: 44100,
    audioChannels: 2
  }.freeze

  module_function

  def media_root = MEDIA_ROOT

  def channel_root(channel_id)
    File.join(MEDIA_ROOT, channel_id.to_s)
  end

  def raw_path(channel_id, uuid, original_name)
    # keep the original name for humans, but namespace by uuid so it's unique
    # (JS \w is ASCII-only, hence the explicit class)
    safe = original_name.to_s.gsub(/[^A-Za-z0-9_.\-]+/, "_")
    safe = safe[-120..] || safe if safe.length > 120
    File.join(channel_root(channel_id), "raw", "#{uuid}_#{safe}")
  end

  # Relative-to-channel-root path stored in channel_media.storage_path.
  def conformed_rel_path(uuid)
    "#{uuid}.mp4"
  end

  def conformed_abs_path(channel_id, uuid)
    File.join(channel_root(channel_id), conformed_rel_path(uuid))
  end

  def ensure_dir(dir)
    FileUtils.mkdir_p(dir) unless File.exist?(dir)
  end

  # Landing dir for in-flight uploads. Deliberately INSIDE MEDIA_ROOT so the
  # final move into the channel's raw dir is a rename, not a byte copy.
  def upload_tmp_dir
    File.join(MEDIA_ROOT, ".uploads")
  end

  # Delete stranded partial uploads older than max_age_ms.
  def sweep_upload_tmp(max_age_ms = 24 * 60 * 60 * 1000)
    dir = upload_tmp_dir
    entries =
      begin
        Dir.children(dir)
      rescue SystemCallError
        return # no dir yet — nothing to sweep
      end
    cutoff = Time.now - (max_age_ms / 1000.0)
    entries.each do |name|
      file = File.join(dir, name)
      begin
        File.unlink(file) if File.stat(file).mtime < cutoff
      rescue SystemCallError
        # raced with another sweep or an active handler — leave it
      end
    end
    nil
  end

  # Free bytes (available to unprivileged users, like statfs bavail*bsize) on
  # the filesystem holding MEDIA_ROOT. Walks up to the nearest existing
  # ancestor so this still answers before the tree has been created. Ruby has
  # no statfs binding in core, so this asks POSIX `df -Pk`. nil = unknown.
  def free_bytes_at_media_root
    probe = MEDIA_ROOT
    until File.exist?(probe)
      parent = File.dirname(probe)
      return nil if parent == probe
      probe = parent
    end
    out, status = Open3.capture2("df", "-Pk", probe)
    return nil unless status.success?
    fields = out.lines[1]&.split
    avail = fields && fields[3]
    return nil unless avail&.match?(/\A\d+\z/)
    avail.to_i * 1024
  rescue SystemCallError, IOError
    nil # df unavailable — caller treats this as "don't block"
  end

  # ffmpeg argv (after `-i <input>`) that produces a house-format file.
  def house_format_args(output)
    f = HOUSE_FORMAT
    vf =
      "scale=#{f[:width]}:#{f[:height]}:force_original_aspect_ratio=decrease," \
      "pad=#{f[:width]}:#{f[:height]}:(ow-iw)/2:(oh-ih)/2," \
      "fps=#{f[:fps]},setsar=1"
    [
      "-vf", vf,
      "-c:v", f[:videoCodec],
      "-preset", f[:preset],
      "-profile:v", "high",
      "-pix_fmt", "yuv420p",
      "-g", f[:gop].to_s,
      "-keyint_min", f[:gop].to_s,
      "-sc_threshold", "0",
      "-c:a", f[:audioCodec],
      "-b:a", f[:audioBitrate],
      "-ar", f[:audioRate].to_s,
      "-ac", f[:audioChannels].to_s,
      "-movflags", "+faststart",
      "-y",
      output
    ]
  end
end
