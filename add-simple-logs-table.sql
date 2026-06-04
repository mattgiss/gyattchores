-- Simple chore logs table for the simplified (frictionless) GyattChores web app.
-- The simplified app uses hardcoded players/chores with short string IDs and a
-- flat log shape, so it gets its own table rather than reusing the legacy
-- UUID-based chore_completions table (which also enforces one-per-day-per-chore).
-- This table is the shared backend that lets every device see the same logs.

CREATE TABLE IF NOT EXISTS simple_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id   TEXT NOT NULL,
    player_name TEXT NOT NULL,
    chore_id    TEXT NOT NULL,
    chore_name  TEXT NOT NULL,
    chore_icon  TEXT,
    points      INTEGER NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_simple_logs_status     ON simple_logs(status);
CREATE INDEX IF NOT EXISTS idx_simple_logs_created_at ON simple_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_simple_logs_player     ON simple_logs(player_id);

-- The app authenticates with the public anon key (same trust model as the
-- original app: approval is gated by an in-app code, not real auth). Enable RLS
-- and allow the anon role to read/write so logging works from any device.
ALTER TABLE simple_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon can read simple_logs"   ON simple_logs;
DROP POLICY IF EXISTS "anon can insert simple_logs" ON simple_logs;
DROP POLICY IF EXISTS "anon can update simple_logs" ON simple_logs;

CREATE POLICY "anon can read simple_logs"
    ON simple_logs FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon can insert simple_logs"
    ON simple_logs FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "anon can update simple_logs"
    ON simple_logs FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

COMMENT ON TABLE simple_logs IS 'Shared chore logs for the simplified web/iOS/watch app (pending/approved/rejected).';
