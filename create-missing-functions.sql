-- Create get_weekly_goat function
CREATE OR REPLACE FUNCTION get_weekly_goat()
RETURNS TABLE (
    player_id UUID,
    player_name TEXT,
    weekly_total INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_monday DATE;
    max_total INTEGER;
BEGIN
    -- Get current week's Monday
    current_monday := DATE_TRUNC('week', CURRENT_DATE)::DATE;

    -- Get max total for this week
    SELECT MAX(total) INTO max_total
    FROM get_weekly_totals(current_monday) wt(id, name, total);

    -- Return all players with max total (handles ties)
    RETURN QUERY
    SELECT id, name, total
    FROM get_weekly_totals(current_monday)
    WHERE total = max_total AND max_total > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION get_weekly_goat() TO anon, authenticated;

-- Create get_current_week_start function
CREATE OR REPLACE FUNCTION get_current_week_start()
RETURNS DATE
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN DATE_TRUNC('week', CURRENT_DATE)::DATE;
END;
$$;

GRANT EXECUTE ON FUNCTION get_current_week_start() TO anon, authenticated;

-- Create get_recent_error_logs function
CREATE OR REPLACE FUNCTION get_recent_error_logs(
    limit_count INTEGER DEFAULT 50,
    error_type_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    error_type TEXT,
    error_message TEXT,
    user_input TEXT,
    device_info JSONB,
    ip_address TEXT,
    user_agent TEXT,
    logged_at TIMESTAMP WITH TIME ZONE
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
        el.user_input,
        el.device_info,
        el.ip_address,
        el.user_agent,
        el.logged_at
    FROM error_logs el
    WHERE (error_type_filter IS NULL OR el.error_type = error_type_filter)
    ORDER BY el.logged_at DESC
    LIMIT limit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_recent_error_logs(INTEGER, TEXT) TO anon, authenticated;

-- Create get_error_stats function
CREATE OR REPLACE FUNCTION get_error_stats()
RETURNS TABLE (
    error_type TEXT,
    count BIGINT,
    last_occurrence TIMESTAMP WITH TIME ZONE
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
        MAX(el.logged_at) as last_occurrence
    FROM error_logs el
    GROUP BY el.error_type
    ORDER BY count DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_error_stats() TO anon, authenticated;

-- Create calculate_tiered_payout function
CREATE OR REPLACE FUNCTION calculate_tiered_payout(
    weekly_points INTEGER,
    player_tier TEXT DEFAULT 'B'
)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    payout NUMERIC := 0;
    tier1_points INTEGER;
    tier2_points INTEGER;
    tier3_points INTEGER;
BEGIN
    -- Option B: Tiered payout system
    IF player_tier = 'B' THEN
        -- Tier 1: First 500 points at $0.01 per point (max $5.00)
        tier1_points := LEAST(weekly_points, 500);
        payout := payout + (tier1_points * 0.01);

        -- Tier 2: Points 501-1000 at $0.008 per point (max $4.00)
        IF weekly_points > 500 THEN
            tier2_points := LEAST(weekly_points - 500, 500);
            payout := payout + (tier2_points * 0.008);
        END IF;

        -- Tier 3: Points 1000+ at $0.005 per point (no cap)
        IF weekly_points > 1000 THEN
            tier3_points := weekly_points - 1000;
            payout := payout + (tier3_points * 0.005);
        END IF;
    END IF;

    RETURN ROUND(payout, 2);
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_tiered_payout(INTEGER, TEXT) TO anon, authenticated;
