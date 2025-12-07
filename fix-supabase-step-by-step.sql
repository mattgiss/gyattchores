-- ============================================
-- STEP 1: CREATE ALL TABLES FIRST
-- ============================================

-- 1A. ERROR_LOGS TABLE
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type TEXT NOT NULL,
    error_message TEXT,
    player_id UUID,
    chore_id UUID,
    stack_trace TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add logged_at if missing (for existing tables)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'error_logs' AND column_name = 'logged_at'
    ) THEN
        ALTER TABLE error_logs ADD COLUMN logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- 1B. BONUSES TABLE
CREATE TABLE IF NOT EXISTS bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL,
    bonus_type TEXT NOT NULL,
    bonus_amount INTEGER NOT NULL DEFAULT 0,
    week_start_date DATE NOT NULL,
    description TEXT,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1C. WEEKLY_RESETS TABLE
CREATE TABLE IF NOT EXISTS weekly_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL UNIQUE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- STEP 2: CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_error_logs_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_logged_at ON error_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_player ON error_logs(player_id);

CREATE INDEX IF NOT EXISTS idx_bonuses_player ON bonuses(player_id);
CREATE INDEX IF NOT EXISTS idx_bonuses_week ON bonuses(week_start_date);
CREATE INDEX IF NOT EXISTS idx_bonuses_type ON bonuses(bonus_type);

CREATE INDEX IF NOT EXISTS idx_weekly_resets_date ON weekly_resets(week_start_date);

-- ============================================
-- STEP 3: ENABLE RLS AND CREATE POLICIES
-- ============================================

-- Error logs
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to error_logs" ON error_logs;
CREATE POLICY "Allow all access to error_logs" ON error_logs FOR ALL USING (true) WITH CHECK (true);

-- Bonuses
ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to bonuses" ON bonuses;
CREATE POLICY "Allow all access to bonuses" ON bonuses FOR ALL USING (true) WITH CHECK (true);

-- Weekly resets
ALTER TABLE weekly_resets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to weekly_resets" ON weekly_resets;
CREATE POLICY "Allow all access to weekly_resets" ON weekly_resets FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- STEP 4: GRANT PERMISSIONS
-- ============================================

GRANT SELECT, INSERT ON error_logs TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON bonuses TO authenticated, anon;
GRANT SELECT, INSERT ON weekly_resets TO authenticated, anon;

-- ============================================
-- STEP 5: DROP OLD FUNCTIONS (if they exist)
-- ============================================

DROP FUNCTION IF EXISTS get_recent_error_logs(INTEGER, TEXT);
DROP FUNCTION IF EXISTS get_weekly_totals(DATE);
DROP FUNCTION IF EXISTS get_weekly_goat();
DROP FUNCTION IF EXISTS get_error_stats();

-- ============================================
-- STEP 6: CREATE FUNCTIONS
-- ============================================

-- 6A. GET_WEEKLY_TOTALS
CREATE FUNCTION get_weekly_totals(week_start DATE)
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
        p.id,
        p.name,
        COALESCE(SUM(cc.value_awarded), 0)::INTEGER
    FROM players p
    LEFT JOIN chore_completions cc ON cc.player_id = p.id
        AND cc.status = 'approved'
        AND cc.completed_date >= week_start
        AND cc.completed_date < week_start + INTERVAL '7 days'
    GROUP BY p.id, p.name
    ORDER BY COALESCE(SUM(cc.value_awarded), 0) DESC;
END;
$$;

-- 6B. GET_WEEKLY_GOAT
CREATE FUNCTION get_weekly_goat()
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
    SELECT MAX(wt.weekly_total) INTO max_total
    FROM get_weekly_totals(current_monday) wt;

    -- Return all players with max total (handles ties)
    RETURN QUERY
    SELECT
        wt.player_id,
        wt.player_name,
        wt.weekly_total
    FROM get_weekly_totals(current_monday) wt
    WHERE wt.weekly_total = max_total AND max_total > 0;
END;
$$;

-- 6C. GET_RECENT_ERROR_LOGS
CREATE FUNCTION get_recent_error_logs(
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
        p.name,
        el.chore_id,
        c.name,
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

-- 6D. GET_ERROR_STATS
CREATE FUNCTION get_error_stats()
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
        COUNT(*),
        MAX(el.logged_at)
    FROM error_logs el
    WHERE el.logged_at >= NOW() - INTERVAL '7 days'
    GROUP BY el.error_type
    ORDER BY COUNT(*) DESC;
END;
$$;

-- ============================================
-- STEP 7: GRANT FUNCTION PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION get_weekly_totals(DATE) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_weekly_goat() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_recent_error_logs(INTEGER, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_error_stats() TO authenticated, anon;

-- ============================================
-- STEP 8: VERIFY EVERYTHING
-- ============================================

-- Check tables
SELECT 'Tables Created:' as status;
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('error_logs', 'bonuses', 'weekly_resets')
ORDER BY table_name;

-- Check functions
SELECT 'Functions Created:' as status;
SELECT routine_name FROM information_schema.routines
WHERE routine_name IN ('get_weekly_totals', 'get_weekly_goat', 'get_recent_error_logs', 'get_error_stats')
ORDER BY routine_name;

SELECT '✅ Setup Complete!' as status;
