-- Tennisnuts Match Predictor — Supabase Schema
-- Run this in the Supabase SQL editor

-- ─────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────
-- TABLES
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS members (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  username     TEXT        UNIQUE NOT NULL,
  display_name TEXT        NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tournaments (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT        NOT NULL,
  year       INT         NOT NULL,
  status     TEXT        NOT NULL DEFAULT 'upcoming'
               CHECK (status IN ('upcoming', 'active', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS matches (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id      UUID        NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  player1            TEXT        NOT NULL,
  player2            TEXT        NOT NULL,
  round              TEXT        NOT NULL,
  format             TEXT        NOT NULL DEFAULT 'best_of_3'
                       CHECK (format IN ('best_of_3', 'best_of_5')),
  favourite_percent  INT         NOT NULL DEFAULT 50
                       CHECK (favourite_percent >= 0 AND favourite_percent <= 100),
  deadline           TIMESTAMPTZ NOT NULL,
  result_winner      TEXT,
  result_sets        TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS predictions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id        UUID        NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  match_id         UUID        NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  predicted_winner TEXT        NOT NULL,
  predicted_sets   TEXT,
  points_earned    INT         NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (member_id, match_id)
);

-- ─────────────────────────────────────────────
-- LEADERBOARD VIEW
-- Scoring: correct winner = 1 pt
--          correct winner + exact sets = 2 pts total
-- Only members with at least one prediction appear.
-- ─────────────────────────────────────────────

CREATE OR REPLACE VIEW leaderboard AS
SELECT
  m.id                                              AS member_id,
  m.display_name,
  m.username,
  t.id                                              AS tournament_id,
  t.name                                            AS tournament_name,
  COALESCE(SUM(p.points_earned), 0)                 AS total_points,
  COUNT(p.id)                                       AS total_predictions,
  COUNT(p.id) FILTER (WHERE p.points_earned > 0)    AS correct_predictions
FROM members m
JOIN predictions p  ON p.member_id = m.id
JOIN matches    mx  ON mx.id = p.match_id
JOIN tournaments t  ON t.id = mx.tournament_id
GROUP BY m.id, m.display_name, m.username, t.id, t.name
HAVING COUNT(p.id) > 0;

GRANT SELECT ON leaderboard TO anon, authenticated;

-- ─────────────────────────────────────────────
-- ROW-LEVEL SECURITY
-- ─────────────────────────────────────────────

ALTER TABLE members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches     ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;

-- Single open "public_all" policy on each table (public prediction game)
DROP POLICY IF EXISTS "public_all" ON members;
CREATE POLICY "public_all" ON members
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_all" ON tournaments;
CREATE POLICY "public_all" ON tournaments
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_all" ON matches;
CREATE POLICY "public_all" ON matches
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_all" ON predictions;
CREATE POLICY "public_all" ON predictions
  FOR ALL USING (true) WITH CHECK (true);
