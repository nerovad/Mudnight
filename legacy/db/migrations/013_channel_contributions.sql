-- Open Source TV: viewers pitch films to a channel's programming, owners accept/decline.
-- Modeled on the pull-request flow: channel = repo, owner = maintainer, contribution = PR.

-- How open a channel is to contributions:
--   'open'   - anyone logged in can pitch
--   'invite' - only users on the channel_contributors list can pitch
--   'closed' - no contributions (default)
ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS contribution_policy TEXT NOT NULL DEFAULT 'closed'
  CHECK (contribution_policy IN ('open', 'invite', 'closed'));

-- Invite list / trusted contributors per channel.
--   'contributor' - may pitch on invite-only channels
--   'trusted'     - pitches are auto-accepted (commit access)
CREATE TABLE IF NOT EXISTS channel_contributors (
  id         BIGSERIAL PRIMARY KEY,
  channel_id BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'contributor' CHECK (role IN ('contributor', 'trusted')),
  invited_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (channel_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_channel_contributors_channel ON channel_contributors(channel_id);

-- A pitched contribution: a film plus an optional proposed schedule slot.
-- proposed_slot jsonb: { scheduled_at, duration_seconds?, recurrence_type?, recurrence_days?, recurrence_end_date?, air_time? }
CREATE TABLE IF NOT EXISTS channel_contributions (
  id               BIGSERIAL PRIMARY KEY,
  channel_id       BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  contributor_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  film_id          BIGINT NOT NULL REFERENCES films(id) ON DELETE CASCADE,
  proposed_slot    JSONB,
  pitch_text       TEXT,
  -- Contributor asserts they hold the rights to the film and grant the
  -- channel permission to broadcast it. Must be true to submit.
  rights_confirmed BOOLEAN NOT NULL DEFAULT false,
  status           TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'accepted', 'declined', 'withdrawn')),
  review_note      TEXT,                -- optional reason on decline (or note on accept)
  reviewed_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contributions_channel_status ON channel_contributions(channel_id, status);
CREATE INDEX IF NOT EXISTS idx_contributions_contributor ON channel_contributions(contributor_id);

-- Attribution pointer: schedule items materialized from an accepted
-- contribution keep a link back to it (contributor credit).
ALTER TABLE channel_schedule
  ADD COLUMN IF NOT EXISTS contribution_id BIGINT REFERENCES channel_contributions(id) ON DELETE SET NULL;
