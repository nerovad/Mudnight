# Periodic work that server.ts started next to `server.listen`:
#   - delete chat messages older than 1h and expired DMs: on boot, then every 10 min
#   - sweep stranded partial uploads in MEDIA_ROOT/.uploads: on boot, then every 6h
#   - playoutSupervisor.configureFromEnv(pool)
#
# Only the web server process runs these — never `rails console`, `rails
# runner`, rake/db tasks or tests. Detection:
#   * `rails server` defines Rails::Server before the app boots;
#   * a bare `puma -C config/puma.rb` (or a puma cluster worker) runs with
#     $PROGRAM_NAME ".../puma" / "puma: cluster worker N: ...".
# Set BACKGROUND_TASKS=0 to force them off, =1 to force them on.
#
# Tasks start in after_initialize (so the app and DB config are fully loaded)
# and are re-created after a fork (ActiveSupport::ForkTracker), because timer
# threads do not survive fork — that covers puma cluster mode with
# preload_app!. Each tick runs inside Rails.application.executor.wrap so DB
# connections are checked in again and code reloading stays safe.
module BackgroundTasks
  CLEANUP_INTERVAL = 10 * 60
  SWEEP_INTERVAL = 6 * 60 * 60

  class << self
    def server_process?
      case ENV["BACKGROUND_TASKS"]
      when "0", "false" then return false
      when "1", "true" then return true
      end
      return true if defined?(Rails::Server)

      File.basename($PROGRAM_NAME.to_s).start_with?("puma") || $PROGRAM_NAME.to_s.start_with?("puma:")
    end

    def start!
      stop!
      @tasks = [
        timer(CLEANUP_INTERVAL) { cleanup_old_messages },
        timer(SWEEP_INTERVAL) { MediaStorage.sweep_upload_tmp }
      ]
    end

    def stop!
      (@tasks || []).each { |t| t.shutdown rescue nil }
      @tasks = []
    end

    def cleanup_old_messages
      result = Db.query("DELETE FROM messages WHERE created_at < NOW() - INTERVAL '1 hour'")
      if result.row_count.to_i > 0
        Rails.logger.info("🧹 Cleaned up #{result.row_count} old messages")
      end

      # Cleanup expired direct messages
      dm_result = Db.query("DELETE FROM direct_messages WHERE expires_at < NOW()")
      if dm_result.row_count.to_i > 0
        Rails.logger.info("🧹 Cleaned up #{dm_result.row_count} expired direct messages")
      end
    rescue StandardError => e
      Rails.logger.error("Error cleaning up old messages: #{e.class}: #{e.message}")
    end

    private

    # run_now: Express ran each task once at startup, then on the interval.
    def timer(interval, &work)
      task = Concurrent::TimerTask.new(execution_interval: interval, run_now: true) do
        Rails.application.executor.wrap(&work)
      rescue StandardError => e
        Rails.logger.error("[background] task failed: #{e.class}: #{e.message}")
      end
      task.execute
      task
    end
  end
end

if BackgroundTasks.server_process?
  # On boot and after every code reload in development (a reload replaces the
  # OnDemandPlayout singleton, which must be re-configured).
  Rails.application.reloader.to_prepare do
    OnDemandPlayout.instance.configure_from_env(Db)
  end

  Rails.application.config.after_initialize do
    BackgroundTasks.start!
    ActiveSupport::ForkTracker.after_fork { BackgroundTasks.start! }
  end
end
