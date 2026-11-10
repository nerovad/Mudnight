BEGIN;

-- One ballot per voter identity per session (logged-in or anon)
CREATE TABLE IF NOT EXISTS ballots (
  id                 BIGSERIAL PRIMARY KEY,
  session_id         BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id            BIGINT REFERENCES users(id) ON DELETE SET NULL,  -- null if anonymous
  fingerprint_sha256 BYTEA,                                           -- anon dedupe hash
  weight             NUMERIC(6,3) NOT NULL DEFAULT 1.0,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uniq_ballot_user UNIQUE (session_id, user_id),
  CONSTRAINT uniq_ballot_fp   UNIQUE (session_id, fingerprint_sha256)
);

CREATE INDEX IF NOT EXISTS idx_ballots_session ON ballots(session_id);
CREATE INDEX IF NOT EXISTS idx_ballots_user    ON ballots(user_id);

-- ===========================
-- R A T I N G S  (partitioned)
-- ===========================
-- Partitioned by session_id; PK must include session_id
CREATE TABLE IF NOT EXISTS ratings (
  session_id BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  id         BIGINT GENERATED ALWAYS AS IDENTITY,
  entry_id   BIGINT NOT NULL REFERENCES session_entries(id) ON DELETE CASCADE,
  ballot_id  BIGINT NOT NULL REFERENCES ballots(id) ON DELETE CASCADE,
  score      NUMERIC(4,2) NOT NULL CHECK (score >= 0 AND score <= 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, id)
) PARTITION BY HASH (session_id);

-- 8 hash partitions
DO $$
DECLARE i int;
BEGIN
  FOR i IN 0..7 LOOP
    EXECUTE format($f$
      CREATE TABLE IF NOT EXISTS ratings_p%s
      PARTITION OF ratings
      FOR VALUES WITH (MODULUS 8, REMAINDER %s);
    $f$, i, i);
  END LOOP;
END$$;

-- Global indexes (created on each partition)
CREATE INDEX IF NOT EXISTS idx_ratings_session_entry
  ON ratings (session_id, entry_id);
CREATE INDEX IF NOT EXISTS idx_ratings_ballot
  ON ratings (ballot_id);

-- Enforce one rating per ballot per entry within a session
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uniq_ratings_one_per_ballot'
  ) THEN
    ALTER TABLE ratings
      ADD CONSTRAINT uniq_ratings_one_per_ballot
      UNIQUE (session_id, entry_id, ballot_id);
  END IF;
END$$;

-- ===========================
-- M A T C H E S  (optional)
-- ===========================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'match_choice') THEN
    CREATE TYPE match_choice AS ENUM ('A', 'B');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS matches (
  id              BIGSERIAL PRIMARY KEY,
  session_id      BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  round           INT NOT NULL,
  position        INT NOT NULL,  -- slot within round
  entry_a_id      BIGINT NOT NULL REFERENCES session_entries(id) ON DELETE CASCADE,
  entry_b_id      BIGINT NOT NULL REFERENCES session_entries(id) ON DELETE CASCADE,
  starts_at       TIMESTAMPTZ,
  ends_at         TIMESTAMPTZ,
  winner_entry_id BIGINT REFERENCES session_entries(id),
  UNIQUE (session_id, round, position)
);

CREATE INDEX IF NOT EXISTS idx_matches_session_round
  ON matches(session_id, round, position);

-- match_votes partitioned by match_id; PK must include match_id
CREATE TABLE IF NOT EXISTS match_votes (
  match_id  BIGINT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  id        BIGINT GENERATED ALWAYS AS IDENTITY,
  ballot_id BIGINT NOT NULL REFERENCES ballots(id) ON DELETE CASCADE,
  choice    match_choice NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, id)
) PARTITION BY HASH (match_id);

-- 8 hash partitions
DO $$
DECLARE i int;
BEGIN
  FOR i IN 0..7 LOOP
    EXECUTE format($f$
      CREATE TABLE IF NOT EXISTS match_votes_p%s
      PARTITION OF match_votes
      FOR VALUES WITH (MODULUS 8, REMAINDER %s);
    $f$, i, i);
  END LOOP;
END$$;

CREATE INDEX IF NOT EXISTS idx_match_votes_match  ON match_votes(match_id);
CREATE INDEX IF NOT EXISTS idx_match_votes_ballot ON match_votes(ballot_id);

-- Enforce one vote per ballot per match
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uniq_match_votes_one_per_ballot'
  ) THEN
    ALTER TABLE match_votes
      ADD CONSTRAINT uniq_match_votes_one_per_ballot
      UNIQUE (match_id, ballot_id);
  END IF;
END$$;

COMMIT;
