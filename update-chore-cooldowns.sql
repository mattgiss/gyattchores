-- Update chore cooldowns to realistic frequencies
-- Run this in Supabase SQL Editor

-- Weekly chores (7 days = 168 hours)
UPDATE chores SET cooldown_hours = 168 WHERE name = 'Vacuum Living Room';
UPDATE chores SET cooldown_hours = 168 WHERE name = 'Take Out Recycling';

-- Every 3 days (72 hours) - prevents over-watering!
UPDATE chores SET cooldown_hours = 72 WHERE name = 'Water Plants';

-- Every 2 days (48 hours)
UPDATE chores SET cooldown_hours = 48 WHERE name = 'Fold Laundry';

-- Daily chores (24 hours)
UPDATE chores SET cooldown_hours = 24 WHERE name = 'Get Mail';
UPDATE chores SET cooldown_hours = 24 WHERE name = 'Clean Room';
UPDATE chores SET cooldown_hours = 24 WHERE name = 'Unload Dishwasher';

-- Twice daily (12 hours)
UPDATE chores SET cooldown_hours = 12 WHERE name = 'Take Out Trash';
UPDATE chores SET cooldown_hours = 12 WHERE name = 'Sweep Floor';

-- Multiple times daily for poop cleanup (10 hours)
UPDATE chores SET cooldown_hours = 10 WHERE name = 'Pick up Poop';

-- Multiple times daily for counter wiping (8 hours = 3x daily)
UPDATE chores SET cooldown_hours = 8 WHERE name = 'Wipe Counters';

-- Meal-based chores (6 hours = breakfast, lunch, dinner)
UPDATE chores SET cooldown_hours = 6 WHERE name = 'Wash Dishes';
UPDATE chores SET cooldown_hours = 6 WHERE name = 'Load Dishwasher';
UPDATE chores SET cooldown_hours = 6 WHERE name = 'Set Table';
UPDATE chores SET cooldown_hours = 6 WHERE name = 'Clear Table';

-- Pet feeding already set to 8 hours (no change needed)
-- Feed Alfred and Feed Chevy remain at 8 hours



