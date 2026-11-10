BEGIN;

ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS stream_key TEXT,
  ADD COLUMN IF NOT EXISTS ingest_app TEXT DEFAULT 'live',  -- nginx-rtmp application name
  ADD COLUMN IF NOT EXISTS playback_path TEXT,              -- e.g. '/hls/{slug}/index.m3u8'
  ADD COLUMN IF NOT EXISTS ingest_notes TEXT;               -- optional diagnostics

-- backfill keys + paths if missing
UPDATE channels
SET stream_key = COALESCE(stream_key, encode(gen_random_bytes(16), 'hex')),
    playback_path = COALESCE(playback_path, '/hls/' || slug || '/index.m3u8');

COMMIT;
