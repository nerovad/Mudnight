# ffplayout day-playlist generation (ported from backend/src/services/playlist.ts).
#
# The guide and the playout read the SAME expanded array: air times are a
# cumulative sum over this program, so nothing can drift. We expand the
# channel's ordered segment list, looping it, until the broadcast day is full;
# ffplayout trims the final clip to land exactly on 24h.
#
# Segment rows come straight from Db.query, so bigint columns (in_ms, out_ms,
# media_duration_ms) arrive as Strings exactly as with node-postgres; the TS
# relied on JS coercion for the arithmetic, so we coerce with Js.number.
module Playlist
  DAY_SECONDS = 86400
  MAX_ITEMS = 100_000 # safety bound against pathological zero-length loops

  module_function

  # Build a full-day playlist by looping `segments` until `target_seconds` of
  # PLAYING time (out - in) is reached. Floats in seconds, wire name `in`,
  # playing time is out - in. `storage_root`, when given, is prefixed to each
  # (relative) storage_path to produce an ABSOLUTE `source`.
  def build_day_playlist(channel_label, date, segments, target_seconds = DAY_SECONDS, storage_root = nil)
    program = []

    total_loop_sec = segments.sum(0.0) do |seg|
      [0, (num(seg["out_ms"]) - num(seg["in_ms"])) / 1000.0].max
    end
    if segments.empty? || total_loop_sec <= 0
      return { "channel" => channel_label, "date" => date, "program" => program }
    end

    filled = 0.0
    i = 0
    while filled < target_seconds && program.length < MAX_ITEMS
      seg = segments[i % segments.length]
      playing = (num(seg["out_ms"]) - num(seg["in_ms"])) / 1000.0
      if playing <= 0
        i += 1
        next
      end

      source =
        if Js.truthy?(storage_root)
          "#{storage_root.sub(%r{/\z}, '')}/#{seg['storage_path']}"
        else
          seg["storage_path"]
        end
      item = {
        "in" => round3(num(seg["in_ms"]) / 1000.0),
        "out" => round3(num(seg["out_ms"]) / 1000.0),
        "duration" => round3(num(seg["media_duration_ms"]) / 1000.0),
        "source" => source
      }
      item["title"] = seg["title"] if Js.truthy?(seg["title"])
      item["category"] = seg["category"] if Js.truthy?(seg["category"])
      program << item

      filled += playing
      i += 1
    end

    { "channel" => channel_label, "date" => date, "program" => program }
  end

  # Math.round(n * 1000) / 1000, rendered like a JS number (252, not 252.0).
  def round3(n)
    js_number((n * 1000 + 0.5).floor / 1000.0)
  end

  # Integral floats serialize without ".0" in JS; mirror that for JSON output.
  def js_number(f)
    f.is_a?(Float) && f.finite? && f == f.floor && f.abs < 1e21 ? f.to_i : f
  end

  def num(v)
    n = Js.number(v)
    n.nil? ? Float::NAN : n.to_f
  end
end
