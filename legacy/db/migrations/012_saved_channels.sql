-- Saved channels: users can save up to 5 channels
CREATE TABLE IF NOT EXISTS saved_channels (
  id        BIGSERIAL PRIMARY KEY,
  user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_channels_user ON saved_channels(user_id);
