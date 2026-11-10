-- Linear channels: playout schema. Backs the ffplayout-driven scheduled mode
-- (see docs/ffplayout-adapter.md). Live mode keeps using the existing
-- OBS -> nginx-rtmp path and needs none of this.
--
-- Ordering is the source of truth for programming; air times are always
-- DERIVED (cumulative sum over durations), never stored. "Now Playing" comes
-- from the as-run log below, reported by the playout engine, not inferred from
-- timecodes.
--
-- The migration runner wraps this file in a single transaction and strips any
-- outer BEGIN/COMMIT, so none is written here.

-- Channel-level playout settings.
--   playout_mode        'live' (OBS, unchanged) or 'scheduled' (ffplayout)
--   broadcast_day_start  where the 24h loop is anchored (day-parting later)
--   playout_token        authenticates the playlist-pull URL ffplayout fetches
ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS playout_mode TEXT NOT NULL DEFAULT 'live'
    CHECK (playout_mode IN ('live', 'scheduled')),
  ADD COLUMN IF NOT EXISTS broadcast_day_start TIME NOT NULL DEFAULT '00:00',
  ADD COLUMN IF NOT EXISTS playout_token TEXT;

-- Hosted media catalogue: one row per uploaded master, after conform-on-ingest.
-- duration_ms is the ffprobe of the CONFORMED file, so it is authoritative and
-- nobody types a timecode. (source_kind='url' is reserved for the later swap to
-- creator-hosted URLs; see spec section 10.)
CREATE TABLE IF NOT EXISTS channel_media (
  id             BIGSERIAL PRIMARY KEY,
  channel_id     BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  storage_path   TEXT NOT NULL,          -- house-format file, relative to the channel storage root
  duration_ms    BIGINT NOT NULL,        -- ffprobe of the conformed output
  source_kind    TEXT NOT NULL DEFAULT 'hosted'
                 CHECK (source_kind IN ('hosted', 'url')),
  original_name  TEXT,
  conform_status TEXT NOT NULL DEFAULT 'pending'
                 CHECK (conform_status IN ('pending', 'ready', 'failed')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (channel_id, storage_path)
);

CREATE INDEX IF NOT EXISTS idx_channel_media_channel ON channel_media(channel_id);

-- A channel's ordered program list. position is the ONLY thing drag-and-drop
-- rewrites; gapped values (100, 200, 300) let a single move touch one row.
-- The same media may appear more than once (a loop), hence media_id not a path.
--   in_ms / out_ms  trim points; playing time = out - in (NOT duration)
CREATE TABLE IF NOT EXISTS channel_segments (
  id              BIGSERIAL PRIMARY KEY,
  channel_id      BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  media_id        BIGINT NOT NULL REFERENCES channel_media(id) ON DELETE CASCADE,
  position        INT NOT NULL,
  in_ms           BIGINT NOT NULL DEFAULT 0,
  out_ms          BIGINT NOT NULL,
  category        TEXT,                   -- 'advertisement' is meaningful to the engine
  contribution_id BIGINT REFERENCES channel_contributions(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_segments_channel_position
  ON channel_segments(channel_id, position);
CREATE INDEX IF NOT EXISTS idx_segments_media ON channel_segments(media_id);

-- As-run log: what ACTUALLY aired, reported by the playout engine on every clip
-- start. This is the ground truth "Now Playing" is built from. is_ingest=true
-- means a live source preempted the playlist.
CREATE TABLE IF NOT EXISTS channel_asrun (
  id          BIGSERIAL PRIMARY KEY,
  channel_id  BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  segment_id  BIGINT REFERENCES channel_segments(id) ON DELETE SET NULL,
  source      TEXT NOT NULL,
  title       TEXT,
  started_at  TIMESTAMPTZ NOT NULL,
  duration_ms BIGINT,
  is_ingest   BOOLEAN NOT NULL DEFAULT false,
  raw         JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_asrun_channel_started
  ON channel_asrun(channel_id, started_at DESC);
