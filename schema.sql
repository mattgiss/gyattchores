-- GyattChores Database Schema
-- Created for Supabase PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Players table
CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    avatar_url TEXT,
    best_week_total INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chores table
CREATE TABLE chores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    base_value INTEGER NOT NULL,
    max_per_day INTEGER DEFAULT 1,
    icon TEXT DEFAULT '⭐',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chore completions table
CREATE TABLE chore_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    chore_id UUID NOT NULL REFERENCES chores(id) ON DELETE CASCADE,
    completed_date DATE NOT NULL DEFAULT CURRENT_DATE,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    value_awarded INTEGER NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    UNIQUE(player_id, chore_id, completed_date)
);

-- Indexes for performance
CREATE INDEX idx_completions_player ON chore_completions(player_id);
CREATE INDEX idx_completions_date ON chore_completions(completed_date);
CREATE INDEX idx_completions_status ON chore_completions(status);

-- Insert default players
INSERT INTO players (name, avatar_url) VALUES
    ('Iris', '👧'),
    ('Mateo', '👦');

-- Insert default chores
INSERT INTO chores (name, base_value, max_per_day, icon) VALUES
    ('Pick up Poop', 500, 1, '💩'),
    ('Vacuum Living Room', 500, 1, '🧹'),
    ('Get Mail', 250, 1, '📬'),
    ('Take Out Trash', 375, 1, '🗑️'),
    ('Wash Dishes', 500, 1, '🧼'),
    ('Load Dishwasher', 625, 1, '🍽️'),
    ('Unload Dishwasher', 500, 1, '📦'),
    ('Clean Room', 750, 1, '🛏️'),
    ('Water Plants', 250, 1, '🌱'),
    ('Feed Pet', 250, 1, '🐕'),
    ('Sweep Floor', 375, 1, '🧹'),
    ('Wipe Counters', 375, 1, '✨'),
    ('Take Out Recycling', 250, 1, '♻️'),
    ('Fold Laundry', 500, 1, '👕'),
    ('Set Table', 250, 1, '🍴'),
    ('Clear Table', 250, 1, '🧽');

-- Function to get weekly totals
CREATE OR REPLACE FUNCTION get_weekly_totals(week_start DATE)
RETURNS TABLE (
    player_id UUID,
    player_name TEXT,
    weekly_total INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.name,
        COALESCE(SUM(cc.value_awarded), 0)::INTEGER as total
    FROM players p
    LEFT JOIN chore_completions cc ON p.id = cc.player_id
        AND cc.completed_date >= week_start
        AND cc.completed_date < week_start + INTERVAL '7 days'
        AND cc.status = 'approved'
    GROUP BY p.id, p.name
    ORDER BY total DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get current week's GOAT(s)
CREATE OR REPLACE FUNCTION get_weekly_goat()
RETURNS TABLE (
    player_id UUID,
    player_name TEXT,
    weekly_total INTEGER
) AS $$
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
$$ LANGUAGE plpgsql;

-- Weekly resets tracking table
CREATE TABLE weekly_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL UNIQUE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX idx_weekly_resets_date ON weekly_resets(week_start_date);

-- Add helper function for current week
CREATE OR REPLACE FUNCTION get_current_week_start()
RETURNS DATE AS $$
BEGIN
    RETURN DATE_TRUNC('week', CURRENT_DATE)::DATE;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE players IS 'Family members who can complete chores';
COMMENT ON TABLE chores IS 'Available chores with point values';
COMMENT ON TABLE chore_completions IS 'Record of completed chores, one per player per day per chore';
COMMENT ON TABLE weekly_resets IS 'Tracks weekly resets to prevent double-resets';
COMMENT ON COLUMN chore_completions.status IS 'pending=awaiting approval, approved=points awarded, rejected=not counted';
