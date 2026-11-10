BEGIN;

-- 1) Add the numeric column if missing
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS channel_id_int BIGINT;

-- 2) Backfill numeric channel ids by joining channels.slug
UPDATE messages m
SET channel_id_int = c.id
FROM channels c
WHERE m.channel_id IS NOT NULL
  AND c.slug = m.channel_id
  AND m.channel_id_int IS NULL;

-- 3) Create FK and index on the numeric column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_messages_channel_numeric'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_channel_numeric
      FOREIGN KEY (channel_id_int)
      REFERENCES channels(id)
      ON UPDATE CASCADE
      ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_messages_channel_int_created
  ON messages(channel_id_int, created_at);

-- 4) Drop old text-FK (if present) and the text column, then rename the new column
DO $$
BEGIN
  -- Drop old FK (slug-based) if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_messages_channel_slug'
  ) THEN
    ALTER TABLE messages DROP CONSTRAINT fk_messages_channel_slug;
  END IF;

  -- Drop old text column if it still exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'channel_id'
          AND data_type IN ('text','character varying')
  ) THEN
    ALTER TABLE messages DROP COLUMN channel_id;
  END IF;

  -- Rename *_int -> channel_id (only if target name is free)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'channel_id_int'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'channel_id'
  ) THEN
    ALTER TABLE messages RENAME COLUMN channel_id_int TO channel_id;
  END IF;
END$$;

-- 5) Optional: enforce NOT NULL if all historical rows have a channel
--    (comment this back in when you’re ready)
-- ALTER TABLE messages ALTER COLUMN channel_id SET NOT NULL;

COMMIT;
