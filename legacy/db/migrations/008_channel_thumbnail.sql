-- Add thumbnail column to channels table
ALTER TABLE channels ADD COLUMN IF NOT EXISTS thumbnail text;
