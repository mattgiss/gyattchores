-- Add error logging system and Option B leveling progression
-- Run this in Supabase SQL Editor

-- 1. Create error_logs table
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type TEXT NOT NULL CHECK (error_type IN ('login_failed', 'app_error', 'admin_failed', 'general')),
    error_message TEXT,
    user_input TEXT,
    device_info JSONB,
    ip_address TEXT,
    user_agent TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_error_logs_type ON error_logs(error_type);
CREATE INDEX idx_error_logs_logged_at ON error_logs(logged_at);
CREATE INDEX idx_error_logs_ip ON error_logs(ip_address);

-- Add comment for documentation
COMMENT ON TABLE error_logs IS 'Logs errors, failed login attempts, and admin access attempts with device data';
COMMENT ON COLUMN error_logs.error_type IS 'Type of error: login_failed, admin_failed, app_error, general';
COMMENT ON COLUMN error_logs.device_info IS 'JSON object with browser, OS, screen size, timezone, etc.';

-- 2. Update levels table with Option B (Medium/Balanced) progression
DELETE FROM levels;

INSERT INTO levels (level_number, xp_required, unlocks) VALUES
    (1, 0, '{"title": "Beginner", "description": "Just getting started"}'),
    (2, 10000, '{"title": "Getting Started", "badge": "🌱"}'),
    (3, 15000, '{"title": "Chore Learner", "badge": "📚"}'),
    (4, 20000, '{"title": "Helper", "badge": "🤝"}'),
    (5, 30000, '{"title": "Hard Worker", "badge": "💪", "perks": ["custom_title"]}'),
    (6, 40000, '{"title": "Dedicated", "badge": "⭐"}'),
    (7, 50000, '{"title": "Committed", "badge": "🎯"}'),
    (8, 55000, '{"title": "Reliable", "badge": "✅"}'),
    (9, 60000, '{"title": "Dependable", "badge": "🔰"}'),
    (10, 60000, '{"title": "Expert Helper", "badge": "🏆", "perks": ["priority_chores"]}'),
    (11, 70000, '{"title": "Pro", "badge": "⚡"}'),
    (12, 75000, '{"title": "Advanced", "badge": "🚀"}'),
    (13, 80000, '{"title": "Elite", "badge": "💎"}'),
    (14, 85000, '{"title": "Master", "badge": "👑"}'),
    (15, 100000, '{"title": "Veteran", "badge": "🎖️", "perks": ["bonus_multiplier_1.05"]}'),
    (16, 110000, '{"title": "Champion", "badge": "🥇"}'),
    (17, 120000, '{"title": "Hero", "badge": "🦸"}'),
    (18, 130000, '{"title": "All-Star", "badge": "⭐⭐"}'),
    (19, 140000, '{"title": "Super Star", "badge": "🌟"}'),
    (20, 150000, '{"title": "Legend", "badge": "👑✨", "perks": ["payout_tier_c", "exclusive_achievements"], "payout_tier": "C"}'),
    (21, 175000, '{"title": "Mythic", "badge": "🔮"}'),
    (22, 200000, '{"title": "Epic", "badge": "⚔️"}'),
    (23, 225000, '{"title": "Immortal", "badge": "♾️"}'),
    (24, 250000, '{"title": "Divine", "badge": "✨👼"}'),
    (25, 300000, '{"title": "Ultimate", "badge": "🌌", "perks": ["bonus_multiplier_1.10", "ultimate_perks"]}');

-- 3. Create function to get recent error logs (for admin panel)
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
) AS $$
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
$$ LANGUAGE plpgsql;

-- 4. Create function to get error log statistics
CREATE OR REPLACE FUNCTION get_error_stats()
RETURNS TABLE (
    error_type TEXT,
    count BIGINT,
    last_occurrence TIMESTAMP WITH TIME ZONE
) AS $$
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
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_recent_error_logs IS 'Returns recent error logs with optional filtering by error type';
COMMENT ON FUNCTION get_error_stats IS 'Returns statistics on error occurrences by type';
