-- ============================================
-- STEP 1: CREATE/UPDATE TABLES
-- This version ADDS missing columns to existing tables
-- ============================================

-- ============================================
-- ERROR_LOGS TABLE
-- ============================================

-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type TEXT NOT NULL,
    error_message TEXT
);

-- Add ALL missing columns one by one

-- Add stack_trace column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'error_logs' AND column_name = 'stack_trace'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN stack_trace TEXT;
    END IF;
END $$;

-- Add logged_at column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'error_logs' AND column_name = 'logged_at'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Add player_id column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'error_logs' AND column_name = 'player_id'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN player_id UUID;
    END IF;
END $$;

-- Add chore_id column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'error_logs' AND column_name = 'chore_id'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN chore_id UUID;
    END IF;
END $$;

-- ============================================
-- BONUSES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL,
    bonus_type TEXT NOT NULL,
    bonus_amount INTEGER NOT NULL DEFAULT 0,
    week_start_date DATE NOT NULL,
    description TEXT,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- WEEKLY_RESETS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS weekly_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL UNIQUE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_error_logs_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_logged_at ON error_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_player ON error_logs(player_id);

CREATE INDEX IF NOT EXISTS idx_bonuses_player ON bonuses(player_id);
CREATE INDEX IF NOT EXISTS idx_bonuses_week ON bonuses(week_start_date);
CREATE INDEX IF NOT EXISTS idx_bonuses_type ON bonuses(bonus_type);

CREATE INDEX IF NOT EXISTS idx_weekly_resets_date ON weekly_resets(week_start_date);

-- ============================================
-- ENABLE RLS & CREATE POLICIES
-- ============================================

ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to error_logs" ON error_logs;
CREATE POLICY "Allow all access to error_logs" ON error_logs FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to bonuses" ON bonuses;
CREATE POLICY "Allow all access to bonuses" ON bonuses FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE weekly_resets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to weekly_resets" ON weekly_resets;
CREATE POLICY "Allow all access to weekly_resets" ON weekly_resets FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT ALL ON error_logs TO authenticated, anon;
GRANT ALL ON bonuses TO authenticated, anon;
GRANT ALL ON weekly_resets TO authenticated, anon;

-- ============================================
-- VERIFY - Show all columns in error_logs
-- ============================================

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'error_logs'
ORDER BY ordinal_position;

-- Should show: id, error_type, error_message, stack_trace, logged_at, player_id, chore_id
