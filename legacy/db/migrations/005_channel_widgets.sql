BEGIN;

-- Add widget configuration to channels
ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS widgets JSONB DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS about_text TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS first_live_at TIMESTAMPTZ DEFAULT NULL;

-- Add missing session fields (currently only added in code)
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS event_type TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS voting_mode TEXT DEFAULT 'ratings',
  ADD COLUMN IF NOT EXISTS require_login BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS tournament_bracket JSONB DEFAULT NULL;

-- Create channel schedule table
CREATE TABLE IF NOT EXISTS channel_schedule (
  id BIGSERIAL PRIMARY KEY,
  channel_id BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  film_id BIGINT REFERENCES films(id) ON DELETE SET NULL,
  title TEXT, -- Fallback if film_id is null
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_seconds INT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'airing', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (channel_id, scheduled_at)
);

CREATE INDEX idx_schedule_channel_time
  ON channel_schedule(channel_id, scheduled_at, status);

-- Backfill widgets for existing channels based on event_type
UPDATE channels c
SET widgets = (
  SELECT CASE
    WHEN s.event_type IN ('film_festival', 'film festival') THEN
      '[{"type": "voting_ballot", "order": 0}, {"type": "leaderboard", "order": 1}]'::jsonb
    WHEN s.event_type IN ('battle_royal', 'battle royal', 'battle_royale', 'battle royale') THEN
      '[{"type": "battle_royale", "order": 0}]'::jsonb
    WHEN s.event_type = 'tournament' THEN
      '[{"type": "tournament_bracket", "order": 0}]'::jsonb
    ELSE NULL
  END
  FROM sessions s
  WHERE s.channel_id = c.id
  ORDER BY s.created_at DESC
  LIMIT 1
)
WHERE c.widgets IS NULL
  AND EXISTS (SELECT 1 FROM sessions WHERE channel_id = c.id);

COMMIT;
