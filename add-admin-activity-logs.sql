-- Create admin activity logs table for tracking administrative actions
-- This logs player name changes and other admin activities

CREATE TABLE IF NOT EXISTS admin_activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_type TEXT NOT NULL CHECK (activity_type IN ('name_change', 'avatar_change', 'player_created', 'player_deleted', 'chore_created', 'chore_deleted', 'other')),
    player_id UUID REFERENCES players(id) ON DELETE SET NULL,
    old_value TEXT,
    new_value TEXT,
    description TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_admin_logs_type ON admin_activity_logs(activity_type);
CREATE INDEX idx_admin_logs_player ON admin_activity_logs(player_id);
CREATE INDEX idx_admin_logs_logged_at ON admin_activity_logs(logged_at);

-- Add comments
COMMENT ON TABLE admin_activity_logs IS 'Logs administrative activities like name changes, avatar changes, etc.';
COMMENT ON COLUMN admin_activity_logs.activity_type IS 'Type of activity: name_change, avatar_change, player_created, etc.';
COMMENT ON COLUMN admin_activity_logs.old_value IS 'Previous value before change';
COMMENT ON COLUMN admin_activity_logs.new_value IS 'New value after change';

-- Function to get recent admin activity logs
CREATE OR REPLACE FUNCTION get_recent_admin_logs(
    limit_count INTEGER DEFAULT 50,
    activity_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    activity_type TEXT,
    player_id UUID,
    player_name TEXT,
    old_value TEXT,
    new_value TEXT,
    description TEXT,
    logged_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        al.id,
        al.activity_type,
        al.player_id,
        p.name as player_name,
        al.old_value,
        al.new_value,
        al.description,
        al.logged_at
    FROM admin_activity_logs al
    LEFT JOIN players p ON al.player_id = p.id
    WHERE activity_filter IS NULL OR al.activity_type = activity_filter
    ORDER BY al.logged_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_recent_admin_logs IS 'Returns recent admin activity logs with optional filtering by activity type';

-- Grant permissions
GRANT SELECT, INSERT ON admin_activity_logs TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_recent_admin_logs(INTEGER, TEXT) TO authenticated, anon;
