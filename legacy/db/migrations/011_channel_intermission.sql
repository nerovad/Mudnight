-- Add intermission_url column to channels table
-- NULL means use the system-wide default intermission screen
ALTER TABLE channels ADD COLUMN IF NOT EXISTS intermission_url text;
