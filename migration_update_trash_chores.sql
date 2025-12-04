-- Migration: Update trash/recycling cooldowns and add new chores
-- Date: 2025-12-03
-- Description:
--   - Change "Take Out Trash" cooldown from 168h (weekly) to 24h (daily)
--   - Change "Take Out Recycling" cooldown from 168h (weekly) to 24h (daily)
--   - Add new chore "Take Trash to Curb"
--   - Add new chore "Take Recyclables to Curb"

-- Update existing chores to have 24-hour cooldown
UPDATE chores
SET cooldown_hours = 24
WHERE name = 'Take Out Trash';

UPDATE chores
SET cooldown_hours = 24
WHERE name = 'Take Out Recycling';

-- Add new chores
INSERT INTO chores (name, base_value, max_per_day, icon, cooldown_hours, is_active)
VALUES
    ('Take Trash to Curb', 375, 1, '🚮', 168, true),
    ('Take Recyclables to Curb', 250, 1, '♻️', 168, true);
