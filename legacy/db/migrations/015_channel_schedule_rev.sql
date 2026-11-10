-- Phase 4: a per-channel schedule revision timestamp.
--
-- Bumped on every channel_segments mutation (add / trim / reorder / delete).
-- The playlist-pull endpoint emits it as Last-Modified, which is how ffplayout
-- decides whether to reload the playlist. Without it, a drag-to-reorder would
-- not change any timestamp and the engine would keep playing the stale order.
--
-- The migration runner wraps this file in a transaction and strips any outer
-- BEGIN/COMMIT, so none is written here.

ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS schedule_rev TIMESTAMPTZ NOT NULL DEFAULT now();
