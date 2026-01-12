-- Add definition of done to "Take Trash to Curb" and add new "Clean Bathroom" chore
-- Run this in Supabase SQL Editor

-- 1. Update "Take Trash to Curb" with a definition of done
UPDATE chores
SET description = 'Take both trash and recycling bins to the curb before trash collection day. Make sure lids are closed and bins are placed at the edge of the driveway.'
WHERE name = 'Take Trash to Curb';

-- 2. Add new "Clean Bathroom" chore
INSERT INTO chores (name, description, base_value, max_per_day, icon, cooldown_hours)
VALUES (
    'Clean Bathroom',
    'Put away personal items, wipe down counter, empty trash, organize shelf, clean toilet, pick up clothes off floor, refresh the towels.',
    750,
    1,
    '🚿',
    24
);

-- Verify the changes
SELECT name, description, base_value, icon, cooldown_hours
FROM chores
WHERE name IN ('Take Trash to Curb', 'Clean Bathroom');
