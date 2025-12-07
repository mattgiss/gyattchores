-- Fix function search_path security warnings
-- This sets an explicit search_path for SECURITY DEFINER functions to prevent privilege escalation

-- Fix get_recent_error_logs
DROP FUNCTION IF EXISTS get_recent_error_logs(integer);
CREATE FUNCTION get_recent_error_logs(limit_count integer DEFAULT 50)
RETURNS TABLE (
    id uuid,
    error_type text,
    error_message text,
    user_id uuid,
    logged_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        el.id,
        el.error_type,
        el.error_message,
        el.user_id,
        el.logged_at
    FROM error_logs el
    ORDER BY el.logged_at DESC
    LIMIT limit_count;
END;
$$;

-- Fix get_error_stats
DROP FUNCTION IF EXISTS get_error_stats();
CREATE FUNCTION get_error_stats()
RETURNS TABLE (
    error_type text,
    count bigint,
    latest_occurrence timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Fix get_weekly_totals
DROP FUNCTION IF EXISTS get_weekly_totals(date);
CREATE FUNCTION get_weekly_totals(week_start date)
RETURNS TABLE (
    player_id uuid,
    player_name text,
    weekly_total integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as player_id,
        p.name as player_name,
        COALESCE(SUM(cc.value_awarded), 0)::integer as weekly_total
    FROM players p
    LEFT JOIN chore_completions cc ON p.id = cc.player_id
        AND DATE(cc.completed_date) >= week_start
        AND DATE(cc.completed_date) < week_start + INTERVAL '7 days'
        AND cc.status = 'approved'
    GROUP BY p.id, p.name
    ORDER BY weekly_total DESC;
END;
$$;

-- Fix get_weekly_goat
DROP FUNCTION IF EXISTS get_weekly_goat();
CREATE FUNCTION get_weekly_goat()
RETURNS TABLE (
    player_id uuid,
    player_name text,
    weekly_total integer,
    points integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_monday date;
    max_total integer;
BEGIN
    -- Get current week's Monday
    current_monday := CASE
        WHEN EXTRACT(DOW FROM CURRENT_DATE) = 0
        THEN (DATE_TRUNC('week', CURRENT_DATE)::date + INTERVAL '1 day' - INTERVAL '7 days')::date
        ELSE (DATE_TRUNC('week', CURRENT_DATE)::date + INTERVAL '1 day')::date
    END;

    -- Get max total for this week
    SELECT MAX(wt.weekly_total) INTO max_total
    FROM get_weekly_totals(current_monday) wt;

    -- Return all players with max total
    RETURN QUERY
    SELECT
        wt.player_id,
        wt.player_name,
        wt.weekly_total,
        wt.weekly_total as points
    FROM get_weekly_totals(current_monday) wt
    WHERE wt.weekly_total = max_total AND max_total > 0;
END;
$$;
