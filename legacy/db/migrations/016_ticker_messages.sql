-- Ticker content moves out of the frontend bundle and into the database.
--
-- Until now the strip was a hardcoded template literal in NewsTicker.tsx, so
-- changing a word meant a rebuild and a deploy. That is why it spent four
-- months advertising an Oscars watch-along for March 16th. It also makes a
-- paid sponsor slot unworkable: a sponsor who wants their copy tweaked cannot
-- be waiting on a release.

CREATE TABLE IF NOT EXISTS ticker_messages (
  id           BIGSERIAL PRIMARY KEY,

  -- 'editorial' - our own copy: announcements, channel plugs, contact info
  -- 'sponsor'   - paid placement. Rendered distinctly and click-tracked.
  kind         TEXT NOT NULL DEFAULT 'editorial'
               CHECK (kind IN ('editorial', 'sponsor')),

  body         TEXT NOT NULL CHECK (length(trim(body)) > 0),

  -- Sponsor only. sponsor_name is the advertiser of record — it labels the
  -- segment on screen and identifies the buyer in click analytics.
  sponsor_name TEXT,
  link_url     TEXT,

  -- Higher sorts earlier in the loop. Mid-loop placement is worth more than
  -- the tail, so this is a pricing lever, not just cosmetics.
  priority     INTEGER NOT NULL DEFAULT 0,

  -- The kill switch. Independent of the date window so a message can be
  -- pulled immediately without losing its schedule.
  active       BOOLEAN NOT NULL DEFAULT true,

  -- Flight dates. NULL start means "already running", NULL end means "until
  -- pulled". A monthly sponsorship sets both and expires on its own rather
  -- than depending on anyone remembering to switch it off.
  starts_at    TIMESTAMPTZ,
  ends_at      TIMESTAMPTZ,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ticker_sponsor_needs_name
    CHECK (kind <> 'sponsor' OR (sponsor_name IS NOT NULL AND length(trim(sponsor_name)) > 0)),
  CONSTRAINT ticker_dates_ordered
    CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
);

-- The public read is "everything live right now, in loop order" on every
-- page load, so index exactly that.
CREATE INDEX IF NOT EXISTS idx_ticker_messages_live
  ON ticker_messages (active, kind, priority DESC, id);

-- Sponsor exclusivity is deliberately NOT a unique constraint.
--
-- The ticker sells as one-sponsor-at-a-time, but sponsorships run in
-- consecutive months and next month's needs to be queued while this month's
-- is still running. A partial unique index on (kind) WHERE active would
-- block exactly that. Exclusivity is enforced at read time instead: the
-- public endpoint returns at most one sponsor, the highest-priority row
-- whose flight window covers now. Overlapping sold flights are a booking
-- error the admin UI warns about, not a write the database refuses.

-- Seed the copy that was hardcoded in NewsTicker.tsx so the strip does not
-- go blank on deploy. The stale Oscars line is intentionally not carried
-- over; re-add it from the admin panel if it is still wanted.
INSERT INTO ticker_messages (body, priority) VALUES
  ('Welcome to CineZoo!', 30),
  ('Click anywhere on screen to navigate channels', 20),
  ('Need to contact us? Email us at cinezoo@gmail.com', 10),
  ('Check out channel 99 for Friday Night Rewind: Live!', 5)
ON CONFLICT DO NOTHING;
