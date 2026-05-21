-- Migration: add_duels.sql
-- Creates the duels table for the Pickup Duel feature.
-- A duel is a same-day competition between two anonymous Picksy friends.
-- Winner = whoever has fewer pickups when the duel ends at midnight.

CREATE TABLE IF NOT EXISTS duels (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id         TEXT         NOT NULL,   -- anonymous device UUID
  opponent_id           TEXT         NOT NULL,   -- anonymous device UUID
  challenger_name       TEXT         NOT NULL DEFAULT 'A friend',
  opponent_name         TEXT         NOT NULL DEFAULT 'A friend',
  status                TEXT         NOT NULL DEFAULT 'pending',
  -- status values: 'pending' | 'active' | 'completed' | 'declined'
  started_at            TIMESTAMPTZ,             -- set when opponent accepts
  ends_at               TIMESTAMPTZ,             -- 23:59:59 of the started_at day
  challenger_pickups    INT          NOT NULL DEFAULT 0,
  opponent_pickups      INT          NOT NULL DEFAULT 0,
  winner_id             TEXT,                    -- challenger_id | opponent_id | 'tie'
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ─── Indexes ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS duels_challenger_idx ON duels (challenger_id, status);
CREATE INDEX IF NOT EXISTS duels_opponent_idx   ON duels (opponent_id,   status);

-- ─── Row Level Security ─────────────────────────────────────────────────────
ALTER TABLE duels ENABLE ROW LEVEL SECURITY;

-- Anyone can insert (create a duel invite)
CREATE POLICY "Anyone can create a duel"
  ON duels FOR INSERT
  WITH CHECK (true);

-- Anyone can read all duels
-- The iOS client always filters by own device_id, so only relevant rows are fetched.
CREATE POLICY "Anyone can read duels"
  ON duels FOR SELECT
  USING (true);

-- Anyone can update a duel (accept, decline, update pickups, finalize)
CREATE POLICY "Anyone can update duels"
  ON duels FOR UPDATE
  USING (true);
