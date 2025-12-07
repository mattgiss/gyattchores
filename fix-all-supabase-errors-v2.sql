-- ============================================
-- FIX ALL SUPABASE ERRORS (CORRECTED)
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. FIX ERROR_LOGS TABLE
-- ============================================

-- Check if error_logs table exists, create if not
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type TEXT NOT NULL,
    error_message TEXT,
    player_id UUID REFERENCES players(id) ON DELETE SET NULL,
    chore_id UUID REFERENCES chores(id) ON DELETE SET NULL,
    stack_trace TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add logged_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'error_logs'
        AND column_name = 'logged_at'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Create indexes for error_logs
CREATE INDEX IF NOT EXISTS idx_error_logs_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_logged_at ON error_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_player ON error_logs(player_id);

-- Grant permissions
GRANT SELECT, INSERT ON error_logs TO authenticated, anon;

-- Add RLS policies
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to error_logs" ON error_logs;
CREATE POLICY "Allow all access to error_logs"
    ON error_logs
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- ============================================
-- 2. CREATE BONUSES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    bonus_type TEXT NOT NULL CHECK (bonus_type IN ('beat_goat', 'personal_best', 'perfect_week', 'early_bird', 'night_owl', 'speed_demon', 'other')),
    bonus_amount INTEGER NOT NULL DEFAULT 0,
    week_start_date DATE NOT NULL,
    description TEXT,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for bonuses
CREATE INDEX IF NOT EXISTS idx_bonuses_player ON bonuses(player_id);
CREATE INDEX IF NOT EXISTS idx_bonuses_week ON bonuses(week_start_date);
CREATE INDEX IF NOT EXISTS idx_bonuses_type ON bonuses(bonus_type);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON bonuses TO authenticated, anon;

-- Add RLS policies
ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to bonuses" ON bonuses;
CREATE POLICY "Allow all access to bonuses"
    ON bonuses
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Add comment
COMMENT ON TABLE bonuses IS 'Tracks weekly bonuses awarded to players (Beat GOAT, Personal Best, etc.)';

-- ============================================
-- 3. CREATE/FIX GET_RECENT_ERROR_LOGS FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_recent_error_logs(
    limit_count INTEGER DEFAULT 50,
    error_type_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    error_type TEXT,
    error_message TEXT,
    player_id UUID,
    player_name TEXT,
    chore_id UUID,
    chore_name TEXT,
    stack_trace TEXT,
    logged_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        el.id,
        el.error_type,
        el.error_message,
        el.player_id,
        p.name as player_name,
        el.chore_id,
        c.name as chore_name,
        el.stack_trace,
        el.logged_at
    FROM error_logs el
    LEFT JOIN players p ON el.player_id = p.id
    LEFT JOIN chores c ON el.chore_id = c.id
    WHERE error_type_filter IS NULL OR el.error_type = error_type_filter
    ORDER BY el.logged_at DESC
    LIMIT limit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_recent_error_logs(INTEGER, TEXT) TO authenticated, anon;

COMMENT ON FUNCTION get_recent_error_logs IS 'Returns recent error logs with optional filtering by error type';

-- ============================================
-- 4. CREATE/FIX GET_WEEKLY_TOTALS FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_weekly_totals(week_start DATE)
RETURNS TABLE (
    player_id UUID,
    player_name TEXT,
    weekly_total INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as player_id,
        p.name as player_name,
        COALESCE(SUM(cc.value_awarded), 0)::INTEGER as weekly_total
    FROM players p
    LEFT JOIN chore_completions cc ON cc.player_id = p.id
        AND cc.status = 'approved'
        AND cc.completed_date >= week_start
        AND cc.completed_date < week_start + INTERVAL '7 days'
    GROUP BY p.id, p.name
    ORDER BY weekly_total DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_weekly_totals(DATE) TO authenticated, anon;

COMMENT ON FUNCTION get_weekly_totals IS 'Returns weekly point totals for all players for a given week';

-- ============================================
-- 5. CREATE/FIX GET_WEEKLY_GOAT FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_weekly_goat()
RETURNS TABLE (
    id UUID,
    name TEXT,
    points INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_monday DATE;
    max_total INTEGER;
BEGIN
    -- Get current week's Monday
    current_monday := DATE_TRUNC('week', CURRENT_DATE)::DATE + INTERVAL '1 day';

    -- If today is Sunday, use last Monday
    IF EXTRACT(DOW FROM CURRENT_DATE) = 0 THEN
        current_monday := current_monday - INTERVAL '7 days';
    END IF;

    -- Get max total for this week
    SELECT MAX(weekly_total) INTO max_total
    FROM get_weekly_totals(current_monday);

    -- Return all players with max total (handles ties)
    RETURN QUERY
    SELECT
        wt.player_id as id,
        wt.player_name as name,
        wt.weekly_total as points
    FROM get_weekly_totals(current_monday) wt
    WHERE wt.weekly_total = max_total AND max_total > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION get_weekly_goat() TO authenticated, anon;

COMMENT ON FUNCTION get_weekly_goat IS 'Returns the current week''s GOAT winner(s) - handles ties';

-- ============================================
-- 6. FIX WEEKLY_RESETS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS weekly_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL UNIQUE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_weekly_resets_date ON weekly_resets(week_start_date);

-- Grant permissions
GRANT SELECT, INSERT ON weekly_resets TO authenticated, anon;

-- Add RLS policies
ALTER TABLE weekly_resets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to weekly_resets" ON weekly_resets;
CREATE POLICY "Allow all access to weekly_resets"
    ON weekly_resets
    FOR ALL
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE weekly_resets IS 'Tracks when weekly GOAT resets occur';

-- ============================================
-- 7. CREATE HELPER FUNCTION: GET_ERROR_STATS
-- ============================================

CREATE OR REPLACE FUNCTION get_error_stats()
RETURNS TABLE (
    error_type TEXT,
    count BIGINT,
    latest_occurrence TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        el.error_type,
        COUNT(*) as count,
        MAX(el.logged_at) as latest_occurrence
    FROM error_logs el
    WHERE el.logged_at >= NOW() - INTERVAL '7 days'
    GROUP BY el.error_type
    ORDER BY count DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_error_stats() TO authenticated, anon;

COMMENT ON FUNCTION get_error_stats IS 'Returns error statistics for the last 7 days';

-- ============================================
-- 8. VERIFICATION QUERIES
-- ============================================

-- Check if all tables exist
SELECT
    'error_logs' as table_name,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'error_logs') as exists
UNION ALL
SELECT
    'bonuses',
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bonuses')
UNION ALL
SELECT
    'weekly_resets',
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'weekly_resets');

-- Check if all functions exist
SELECT
    'get_recent_error_logs' as function_name,
    EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_recent_error_logs') as exists
UNION ALL
SELECT
    'get_weekly_goat',
    EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_weekly_goat')
UNION ALL
SELECT
    'get_weekly_totals',
    EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_weekly_totals')
UNION ALL
SELECT
    'get_error_stats',
    EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_error_stats');

-- ============================================
-- DONE!
-- ============================================
-- All errors should now be fixed.
-- Refresh your app and check the console.
-- ============================================
