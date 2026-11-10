# Pure helpers for the on-demand playout supervisor
# (ported from backend/src/services/playoutResolve.ts).
#
# ffplayout playlist mode is wall-clock synced — when its engine starts mid-day
# it joins the loop at the right offset on its own, so the supervisor only
# decides start/stop. resolve_now_playing is for Cinezoo's own knowledge.
module PlayoutResolve
  Resolved = Struct.new(:index, :offset_ms, :segment, keyword_init: true)
  TransitionPlan = Struct.new(:start, :schedule_stop, :cancel_stop, keyword_init: true)

  module_function

  # Given a looping segment list (each with "playing_ms" or :playing_ms)
  # anchored at anchor_ms, what is airing at now_ms and how far into it.
  # nil for an empty/zero-length loop.
  def resolve_now_playing(segments, anchor_ms, now_ms)
    total_loop = segments.sum { |seg| [0, playing_ms(seg)].max }
    return nil if segments.empty? || total_loop <= 0

    # Position within the loop, robust to now < anchor (negative): Ruby's %
    # is already a floored modulo, matching the TS double-mod.
    elapsed = (now_ms - anchor_ms) % total_loop

    acc = 0
    segments.each_with_index do |seg, i|
      dur = [0, playing_ms(seg)].max
      next if dur == 0
      return Resolved.new(index: i, offset_ms: elapsed - acc, segment: seg) if elapsed < acc + dur
      acc += dur
    end
    # Floating-point tail: land on the last non-empty segment.
    (segments.length - 1).downto(0) do |i|
      return Resolved.new(index: i, offset_ms: 0, segment: segments[i]) if playing_ms(segments[i]) > 0
    end
    nil
  end

  # Anchor = the given day's broadcast_day_start (local time), as epoch ms.
  def day_anchor_ms(day_start_hhmm, now_ms)
    parts = (Js.truthy?(day_start_hhmm) ? day_start_hhmm : "00:00").split(":", -1).map { |n| Js.parse_int(n) || 0 }
    h, m = parts
    return Float::NAN if m.nil? # JS setHours(h, undefined) => Invalid Date

    d = Time.at(now_ms / 1000.0).localtime
    midnight = Time.local(d.year, d.month, d.day)
    anchor_t =
      if h.between?(0, 23) && m.between?(0, 59)
        Time.local(d.year, d.month, d.day, h, m, 0)
      else
        midnight + (h * 3600) + (m * 60) # setHours overflow semantics
      end
    anchor = (anchor_t.to_r * 1000).to_i
    # If we're before today's day-start, the current broadcast day began yesterday.
    anchor -= 86_400_000 if anchor > now_ms
    anchor
  end

  # Pure decision: given current per-channel engine statuses
  # ({slug => "running" | "stopping"}) and the set of channel slugs with >= 1
  # viewer, what transitions should happen.
  def plan_transitions(statuses, active_slugs)
    start = []
    schedule_stop = []
    cancel_stop = []

    active_slugs.each do |slug|
      st = statuses[slug]
      if st.nil? then start << slug
      elsif st == "stopping" then cancel_stop << slug
      end
      # "running" -> nothing to do
    end
    statuses.each do |slug, st|
      schedule_stop << slug if st == "running" && !active_slugs.include?(slug)
    end
    TransitionPlan.new(start: start, schedule_stop: schedule_stop, cancel_stop: cancel_stop)
  end

  def playing_ms(seg)
    v = seg.is_a?(Hash) ? (seg.key?("playing_ms") ? seg["playing_ms"] : seg[:playing_ms]) : seg.playing_ms
    Js.number(v) || 0
  end
end
