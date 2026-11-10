BEGIN;

-- Add tags column to channels for metadata tagging
ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT NULL;

-- Create index for tag searching
CREATE INDEX IF NOT EXISTS idx_channels_tags ON channels USING GIN (tags);

COMMIT;
