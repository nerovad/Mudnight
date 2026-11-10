BEGIN;

-- Direct messages table for user-to-user messaging
CREATE TABLE IF NOT EXISTS direct_messages (
  id          BIGSERIAL PRIMARY KEY,
  sender_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content     TEXT NOT NULL,
  read        BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours'
);

-- Index for fetching conversation between two users
CREATE INDEX IF NOT EXISTS idx_dm_conversation
  ON direct_messages(LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id), created_at DESC);

-- Index for fetching unread message counts
CREATE INDEX IF NOT EXISTS idx_dm_unread
  ON direct_messages(receiver_id, read) WHERE read = false;

-- Index for cleanup of expired messages
CREATE INDEX IF NOT EXISTS idx_dm_expires
  ON direct_messages(expires_at) WHERE expires_at IS NOT NULL;

-- Index for getting user's conversations (most recent first)
CREATE INDEX IF NOT EXISTS idx_dm_user_created
  ON direct_messages(sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dm_receiver_created
  ON direct_messages(receiver_id, created_at DESC);

COMMIT;
