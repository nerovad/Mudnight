BEGIN;

-- Channels (numeric PK for joins; slug for human/room IDs)
CREATE TABLE IF NOT EXISTS channels (
  id         BIGSERIAL PRIMARY KEY,
  slug       TEXT UNIQUE NOT NULL,          -- e.g. 'channel-1'
  name       TEXT NOT NULL,
  stream_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed channels from existing messages.channel_id (TEXT slugs)
INSERT INTO channels (slug, name)
SELECT DISTINCT m.channel_id AS slug,
       COALESCE(NULLIF(INITCAP(REPLACE(m.channel_id, '-', ' ')), ''), 'Unnamed Channel') AS name
FROM messages m
WHERE m.channel_id IS NOT NULL
ON CONFLICT (slug) DO NOTHING;

-- FK: messages.channel_id (TEXT) -> channels.slug
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_messages_channel_slug'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_channel_slug
      FOREIGN KEY (channel_id)
      REFERENCES channels(slug)
      ON UPDATE CASCADE
      ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_messages_channel_created
  ON messages(channel_id, created_at);

-- Sessions (one event window per channel)
CREATE TABLE IF NOT EXISTS sessions (
  id           BIGSERIAL PRIMARY KEY,
  channel_id   BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  starts_at    TIMESTAMPTZ NOT NULL,
  ends_at      TIMESTAMPTZ,
  status       TEXT NOT NULL DEFAULT 'scheduled',  -- scheduled|live|closed|archived
  timezone     TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uniq_channel_start UNIQUE (channel_id, starts_at)
);

CREATE INDEX IF NOT EXISTS idx_sessions_time
  ON sessions(channel_id, starts_at, ends_at);

-- Optional: link chat rows to a specific session
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS session_id BIGINT REFERENCES sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_messages_session_created
  ON messages(session_id, created_at);

-- Films catalog
CREATE TABLE IF NOT EXISTS films (
  id              BIGSERIAL PRIMARY KEY,
  title           TEXT NOT NULL,
  creator_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  runtime_seconds INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lineup of films inside a session (order matters)
CREATE TABLE IF NOT EXISTS session_entries (
  id          BIGSERIAL PRIMARY KEY,
  session_id  BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  film_id     BIGINT NOT NULL REFERENCES films(id) ON DELETE CASCADE,
  order_index INT,
  UNIQUE (session_id, film_id),
  UNIQUE (session_id, order_index)
);

CREATE INDEX IF NOT EXISTS idx_session_entries_session
  ON session_entries(session_id, order_index);

COMMIT;
