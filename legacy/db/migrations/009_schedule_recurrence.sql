BEGIN;

-- Add recurrence columns to channel_schedule
ALTER TABLE channel_schedule
  ADD COLUMN IF NOT EXISTS recurrence_type TEXT DEFAULT 'once'
    CHECK (recurrence_type IN ('once', 'daily', 'weekly', 'weekdays', 'weekends')),
  ADD COLUMN IF NOT EXISTS recurrence_days INT[] DEFAULT NULL,  -- 0=Sun, 1=Mon, ..., 6=Sat (for 'weekly' type)
  ADD COLUMN IF NOT EXISTS recurrence_end_date DATE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS air_time TIME DEFAULT NULL;  -- Time of day for recurring shows

-- Add index for efficient recurrence queries
CREATE INDEX IF NOT EXISTS idx_schedule_recurrence
  ON channel_schedule(channel_id, recurrence_type)
  WHERE recurrence_type != 'once';

COMMIT;
