-- Migration: Remove duplicate curb chores
-- Date: 2025-12-03
-- Description:
--   - Remove duplicate "Take Recyclables to Curb" entries, keeping only one
--   - Remove duplicate "Take Trash to Curb" entries, keeping only one

-- Delete duplicate "Take Recyclables to Curb", keeping only the one with the lowest id (oldest)
DELETE FROM chores
WHERE name = 'Take Recyclables to Curb'
AND id NOT IN (
    SELECT MIN(id)
    FROM chores
    WHERE name = 'Take Recyclables to Curb'
);

-- Delete duplicate "Take Trash to Curb", keeping only the one with the lowest id (oldest)
DELETE FROM chores
WHERE name = 'Take Trash to Curb'
AND id NOT IN (
    SELECT MIN(id)
    FROM chores
    WHERE name = 'Take Trash to Curb'
);
