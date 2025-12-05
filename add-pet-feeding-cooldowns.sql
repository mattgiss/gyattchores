-- Add cooldown_hours column to chores table and create separate feeding chores
-- Run this in Supabase SQL Editor

-- First, add the cooldown_hours column if it doesn't exist
ALTER TABLE chores ADD COLUMN IF NOT EXISTS cooldown_hours INTEGER DEFAULT 24;

-- Delete the old "Feed Pet" chore
DELETE FROM chores WHERE name = 'Feed Pet';

-- Add two new pet feeding chores with 8-hour cooldowns
INSERT INTO chores (name, description, base_value, max_per_day, icon, cooldown_hours) VALUES
    ('Feed Alfred', 'Fill Alfred''s food bowl with one scoop of food. Make sure his water bowl is full with fresh water. Check that both bowls are clean.', 250, 1, '🐕', 8),
    ('Feed Chevy', 'Fill Chevy''s food bowl with one scoop of food. Make sure her water bowl is full with fresh water. Check that both bowls are clean.', 250, 1, '🐈', 8);

-- Update all existing chores to have 24-hour cooldown (default)
UPDATE chores SET cooldown_hours = 24 WHERE cooldown_hours IS NULL;
