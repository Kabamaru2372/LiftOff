-- Migration: add_messages.sql
-- Adds public_key column to device_tokens and creates the messages table.

-- ─── device_tokens: add public key column ─────────────────────────────────
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS public_key TEXT;

-- ─── Messages table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_device_id   TEXT         NOT NULL,
  receiver_device_id TEXT         NOT NULL,
  encrypted_text     TEXT         NOT NULL,
  sent_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  is_read            BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ─── Row Level Security ────────────────────────────────────────────────────
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Anyone can insert (sender sends a message)
CREATE POLICY "Anyone can send messages"
  ON messages FOR INSERT
  WITH CHECK (true);

-- Anyone can read messages
-- The iOS app always filters by receiver_device_id = own device_id,
-- so data is only fetched by the intended recipient in practice.
CREATE POLICY "Anyone can read messages"
  ON messages FOR SELECT
  USING (true);

-- Anyone can mark messages as read
CREATE POLICY "Anyone can update messages"
  ON messages FOR UPDATE
  USING (true);

-- ─── Indexes ───────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS messages_receiver_idx
  ON messages (receiver_device_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS messages_sender_idx
  ON messages (sender_device_id);
