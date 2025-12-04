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
    ('BeKindHearted', '👧'),
    ('MegoDinoLava', '👦');

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

-- Bonuses table for tracking weekly bonuses
CREATE TABLE bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    bonus_type TEXT NOT NULL CHECK (bonus_type IN ('beat_goat', 'beat_personal_best')),
    bonus_amount INTEGER NOT NULL,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(player_id, week_start_date, bonus_type)
);

-- Index for bonuses
CREATE INDEX idx_bonuses_player_week ON bonuses(player_id, week_start_date);

-- Achievement System Tables

-- Achievements definition table
CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('chore_milestone', 'point_milestone', 'weekly_performance', 'streak', 'special')),
    requirement_type TEXT NOT NULL CHECK (requirement_type IN ('total_chores', 'total_points', 'goat_wins', 'streak_days', 'week_points', 'special')),
    requirement_value INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Player achievements tracking
CREATE TABLE player_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    progress_data JSONB,
    UNIQUE(player_id, achievement_id)
);

-- Player stats for achievement tracking
CREATE TABLE player_stats (
    player_id UUID PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
    total_chores_completed INTEGER DEFAULT 0,
    total_points_earned INTEGER DEFAULT 0,
    goat_wins INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    early_bird_count INTEGER DEFAULT 0,
    night_owl_count INTEGER DEFAULT 0,
    personal_best_beats INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_player_achievements_player ON player_achievements(player_id);
CREATE INDEX idx_player_achievements_achievement ON player_achievements(achievement_id);
CREATE INDEX idx_achievements_category ON achievements(category);

-- Insert achievement definitions
INSERT INTO achievements (name, description, icon, category, requirement_type, requirement_value) VALUES
-- Chore Milestones
('First Steps', 'Complete your first chore', '🌱', 'chore_milestone', 'total_chores', 1),
('Getting Started', 'Complete 10 chores', '🔰', 'chore_milestone', 'total_chores', 10),
('Chore Champion', 'Complete 50 chores', '💪', 'chore_milestone', 'total_chores', 50),
('Hundred Club', 'Complete 100 chores', '🎯', 'chore_milestone', 'total_chores', 100),
('Chore Master', 'Complete 250 chores', '⭐', 'chore_milestone', 'total_chores', 250),
('Chore Legend', 'Complete 500 chores', '👑', 'chore_milestone', 'total_chores', 500),

-- Point Milestones
('Point Starter', 'Earn 1,000 total points', '💵', 'point_milestone', 'total_points', 1000),
('Point Collector', 'Earn 5,000 total points', '💸', 'point_milestone', 'total_points', 5000),
('Point Master', 'Earn 10,000 total points', '🤑', 'point_milestone', 'total_points', 10000),
('Point Legend', 'Earn 25,000 total points', '💎', 'point_milestone', 'total_points', 25000),

-- Weekly Performance
('First GOAT', 'Win GOAT of the Week', '🐐', 'weekly_performance', 'goat_wins', 1),
('GOAT Dynasty', 'Win GOAT 3 times', '🔥', 'weekly_performance', 'goat_wins', 3),
('GOAT Domination', 'Win GOAT 5 times', '👑', 'weekly_performance', 'goat_wins', 5),
('High Roller', 'Earn 5,000+ points in one week', '🚀', 'weekly_performance', 'week_points', 5000),

-- Streaks
('Daily Dedication', 'Complete chores 3 days in a row', '📅', 'streak', 'streak_days', 3),
('Weekly Warrior', 'Complete chores 7 days in a row', '🗓️', 'streak', 'streak_days', 7),
('Unstoppable', 'Complete chores 14 days in a row', '🔥', 'streak', 'streak_days', 14),
('Legendary', 'Complete chores 30 days in a row', '💫', 'streak', 'streak_days', 30),

-- Special
('Early Bird', 'Complete 5 chores before noon', '🌅', 'special', 'special', 5),
('Night Owl', 'Complete 5 chores after 6 PM', '🌙', 'special', 'special', 5),
('Speed Demon', 'Complete 5 chores in one day', '⚡', 'special', 'special', 5),
('Overachiever', 'Beat your personal best 3 times', '🎖️', 'special', 'special', 3);

-- Initialize player_stats for existing players
INSERT INTO player_stats (player_id)
SELECT id FROM players
ON CONFLICT (player_id) DO NOTHING;

-- Comments for documentation
COMMENT ON TABLE players IS 'Family members who can complete chores';
COMMENT ON TABLE chores IS 'Available chores with point values';
COMMENT ON TABLE chore_completions IS 'Record of completed chores, one per player per day per chore';
COMMENT ON TABLE weekly_resets IS 'Tracks weekly resets to prevent double-resets';
COMMENT ON TABLE bonuses IS 'Weekly bonus awards (beat GOAT, beat personal best)';
COMMENT ON TABLE achievements IS 'Available achievements that can be earned';
COMMENT ON TABLE player_achievements IS 'Tracks which achievements each player has earned';
COMMENT ON TABLE player_stats IS 'Player statistics for achievement tracking';
COMMENT ON COLUMN chore_completions.status IS 'pending=awaiting approval, approved=points awarded, rejected=not counted';
