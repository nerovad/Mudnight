require "singleton"
require "set"

# On-demand playout supervisor (ported from backend/src/services/onDemandPlayout.ts).
#
# Starts a channel's ffplayout engine on the FIRST viewer and tears it down a
# grace period after the LAST viewer leaves, so idle channels cost nothing.
# Fed by ChatChannel's per-channel viewer counts via
# `OnDemandPlayout.instance.sync_viewer_counts(slugs)`. Disabled by default
# (PLAYOUT_ONDEMAND_ENABLED) and defaults to the logging driver.
#
# Node ran this on one event loop; here callers arrive on many threads
# (ActionCable workers, Puma request threads, timer threads), so all state is
# guarded by one monitor. The synchronous part of each JS method runs under
# the lock; the parts after an `await` (DB eligibility check, driver calls)
# run on Concurrent::Promises' IO pool inside a Rails executor, outside the
# lock, with the same re-checks the TS did after resuming.
class OnDemandPlayout
  include Singleton

  DEFAULT_GRACE_MS = 90_000

  def initialize
    @lock = Monitor.new
    @pool = nil
    @driver = EngineDriver::LoggingEngineDriver.new
    @enabled = false
    @grace_ms = DEFAULT_GRACE_MS

    # Per-channel engine status. Absent = no engine. "stopping" = in grace.
    @status = {}
    # slug -> [token, Concurrent::ScheduledTask]
    @teardown_timers = {}
    # slug -> EngineDriver::Channel (positives only)
    @eligible = {}
  end

  def configure_from_env(pool = Db)
    @lock.synchronize do
      @pool = pool
      @enabled = (Js.truthy?(ENV["PLAYOUT_ONDEMAND_ENABLED"]) ? ENV["PLAYOUT_ONDEMAND_ENABLED"] : "false").downcase == "true"
      grace = Js.number(ENV["PLAYOUT_GRACE_MS"])
      @grace_ms = Js.truthy?(grace) ? grace : DEFAULT_GRACE_MS
      @driver = EngineDriver.from_env(pool)
      Rails.logger.info("[playout] on-demand supervisor enabled (grace #{@grace_ms}ms)") if @enabled
    end
    self
  end

  def enabled? = @enabled

  # Called whenever viewer counts change, with the channel slugs that
  # currently have >= 1 viewer (Set or Array).
  def sync_viewer_counts(active_slugs)
    active = active_slugs.is_a?(Set) ? active_slugs : Set.new(Array(active_slugs))
    to_start = []
    @lock.synchronize do
      return unless @enabled && @pool

      plan = PlayoutResolve.plan_transitions(@status, active)

      plan.cancel_stop.each do |slug|
        cancel_timer(slug)
        @status[slug] = "running"
      end
      plan.schedule_stop.each do |slug|
        @status[slug] = "stopping"
        schedule_teardown(slug)
      end
      plan.start.each do |slug|
        # Mark running optimistically so rapid ticks don't double-start; the
        # async eligibility check may clear it back to absent.
        @status[slug] = "running"
        to_start << slug
      end
    end
    to_start.each { |slug| async { start_if_eligible(slug) } }
    nil
  end

  # A viewer just tuned to this channel over HTTP — start its engine now.
  # Only ever *starts*; viewer counts remain the sole authority on teardown.
  # Returns immediately (the start runs in the background), like the
  # controller's `void playoutSupervisor.tuneIn(slug)`.
  def tune_in(slug)
    @lock.synchronize do
      return unless @enabled && @pool && Js.truthy?(slug)

      st = @status[slug]
      return if st == "running" # already up
      if st == "stopping"
        # Caught it inside the grace window — keep the engine we already have.
        cancel_timer(slug)
        @status[slug] = "running"
        return
      end
      @status[slug] = "running"
    end
    async { start_if_eligible(slug) }
    nil
  end

  # Drop cached eligibility for a channel (call when its schedule/mode changes).
  def invalidate(slug)
    @lock.synchronize { @eligible.delete(slug) }
  end

  # Debug/test helper: a copy of the per-channel status map.
  def status_snapshot
    @lock.synchronize { @status.dup }
  end

  private

  def schedule_teardown(slug)
    cancel_timer(slug)
    token = Object.new
    delay = [@grace_ms.to_f, 0].max / 1000.0
    task = Concurrent::ScheduledTask.execute(delay) do
      Rails.application.executor.wrap { teardown(slug, token) }
    rescue StandardError => e
      Rails.logger.error("[playout] teardown errored for #{slug}: #{e.class}: #{e.message}")
    end
    @teardown_timers[slug] = [token, task]
  end

  def cancel_timer(slug)
    entry = @teardown_timers.delete(slug)
    entry&.last&.cancel
  end

  def start_if_eligible(slug)
    channel = resolve_eligible(slug)
    driver = nil
    @lock.synchronize do
      unless channel
        # Not a provisioned scheduled channel with ready segments — forget it
        # so we don't hold a phantom "running" status.
        @status.delete(slug) if @status[slug] == "running"
        return
      end
      return unless @status[slug] == "running" # viewers left during the check
      driver = @driver
    end
    begin
      driver.start(channel)
    rescue StandardError => e
      Rails.logger.error("[playout] start failed for #{slug}: #{e.class}: #{e.message}")
      @lock.synchronize { @status.delete(slug) }
    end
  end

  def teardown(slug, token)
    channel = nil
    driver = nil
    @lock.synchronize do
      entry = @teardown_timers[slug]
      # A cancelled/superseded timer that fired anyway must not act.
      return unless entry && entry.first.equal?(token)

      @teardown_timers.delete(slug)
      return unless @status[slug] == "stopping" # viewers returned
      channel = @eligible[slug]
      @status.delete(slug)
      driver = @driver
    end
    return unless channel

    begin
      driver.stop(channel)
    rescue StandardError => e
      Rails.logger.error("[playout] stop failed for #{slug}: #{e.class}: #{e.message}")
    end
  end

  # Is this a provisioned, scheduled channel with at least one ready segment?
  # Only positives are cached (needed at teardown).
  def resolve_eligible(slug)
    cached = @lock.synchronize { @eligible[slug] }
    return cached if cached

    channel = nil
    begin
      rows = @pool.query(
        "SELECT c.id, c.slug, c.playout_token,
                (SELECT count(*) FROM channel_segments s
                   JOIN channel_media m ON m.id = s.media_id
                  WHERE s.channel_id = c.id AND m.conform_status = 'ready') AS ready_segments
           FROM channels c
          WHERE c.slug = $1 AND c.playout_mode = 'scheduled' AND c.playout_token IS NOT NULL
          LIMIT 1",
        [slug]
      ).rows
      if rows.any? && (Js.number(rows[0]["ready_segments"]) || 0) > 0
        # One ffplayout process per channel -> its internal channel id is 1.
        channel = EngineDriver::Channel.new(id: rows[0]["id"], slug: rows[0]["slug"], ffplayout_channel_id: 1)
      end
    rescue StandardError => e
      Rails.logger.error("[playout] eligibility check failed for #{slug}: #{e.class}: #{e.message}")
    end
    @lock.synchronize { @eligible[slug] = channel } if channel
    channel
  end

  def async(&block)
    Concurrent::Promises.future do
      Rails.application.executor.wrap(&block)
    rescue StandardError => e
      Rails.logger.error("[playout] background task errored: #{e.class}: #{e.message}")
    end
  end
end
