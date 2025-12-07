-- ============================================
-- STEP 2: CREATE FUNCTIONS ONLY
-- Run this AFTER step 1 succeeds
-- ============================================

-- Drop existing functions first
DROP FUNCTION IF EXISTS get_weekly_totals(DATE);
DROP FUNCTION IF EXISTS get_weekly_goat();
DROP FUNCTION IF EXISTS get_recent_error_logs(INTEGER, TEXT);
DROP FUNCTION IF EXISTS get_error_stats();

-- ============================================
-- Function 1: get_weekly_totals
-- ============================================
CREATE OR REPLACE FUNCTION get_weekly_totals(week_start DATE)
RETURNS TABLE (
    player_id UUID,
    player_name TEXT,
    weekly_total INTEGER
)
LANGUAGE sql
SECURITY DEFINER
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION get_weekly_totals(DATE) TO authenticated, anon;

-- ============================================
-- Function 2: get_weekly_goat
-- ============================================
CREATE OR REPLACE FUNCTION get_weekly_goat()
RETURNS TABLE (
    id UUID,
    name TEXT,
    points INTEGER
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    WITH current_week AS (
        SELECT
            CASE
                WHEN EXTRACT(DOW FROM CURRENT_DATE) = 0
                THEN (DATE_TRUNC('week', CURRENT_DATE)::DATE + INTERVAL '1 day' - INTERVAL '7 days')::DATE
                ELSE (DATE_TRUNC('week', CURRENT_DATE)::DATE + INTERVAL '1 day')::DATE
            END as monday
    ),
    weekly_totals AS (
        SELECT * FROM get_weekly_totals((SELECT monday FROM current_week))
    ),
    max_points AS (
        SELECT MAX(weekly_total) as max_total FROM weekly_totals
    )
    SELECT
        wt.player_id as id,
        wt.player_name as name,
        wt.weekly_total as points
    FROM weekly_totals wt, max_points mp
    WHERE wt.weekly_total = mp.max_total
        AND mp.max_total > 0;
$$;

GRANT EXECUTE ON FUNCTION get_weekly_goat() TO authenticated, anon;

-- ============================================
-- Function 3: get_recent_error_logs
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
LANGUAGE sql
SECURITY DEFINER
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION get_recent_error_logs(INTEGER, TEXT) TO authenticated, anon;

-- ============================================
-- Function 4: get_error_stats
-- ============================================
CREATE OR REPLACE FUNCTION get_error_stats()
RETURNS TABLE (
    error_type TEXT,
    count BIGINT,
    latest_occurrence TIMESTAMP WITH TIME ZONE
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT
        el.error_type,
        COUNT(*) as count,
        MAX(el.logged_at) as latest_occurrence
    FROM error_logs el
    WHERE el.logged_at >= NOW() - INTERVAL '7 days'
    GROUP BY el.error_type
    ORDER BY count DESC;
$$;

GRANT EXECUTE ON FUNCTION get_error_stats() TO authenticated, anon;

-- ============================================
-- Verify all functions created
-- ============================================
SELECT routine_name as function_name, routine_type
FROM information_schema.routines
WHERE routine_name IN ('get_weekly_totals', 'get_weekly_goat', 'get_recent_error_logs', 'get_error_stats')
ORDER BY routine_name;
