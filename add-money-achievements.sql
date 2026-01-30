-- Add lifetime earnings achievement type and money milestones
-- Run this in your Supabase SQL Editor

-- Update the CHECK constraint to allow 'lifetime_earnings' requirement type
ALTER TABLE achievements DROP CONSTRAINT IF EXISTS achievements_requirement_type_check;
ALTER TABLE achievements ADD CONSTRAINT achievements_requirement_type_check
    CHECK (requirement_type IN ('total_chores', 'total_points', 'goat_wins', 'streak_days', 'week_points', 'special', 'lifetime_earnings'));

-- Insert money milestone achievements (requirement_value in cents)
INSERT INTO achievements (name, description, icon, category, requirement_type, requirement_value) VALUES
    ('Money Maker', 'Earn $500 lifetime in GyattChores', '💰', 'point_milestone', 'lifetime_earnings', 50000),
    ('Thousandaire', 'Earn $1,000 lifetime in GyattChores', '🏦', 'point_milestone', 'lifetime_earnings', 100000);
