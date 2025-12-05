-- Remove duplicate Feed Alfred and Feed Chevy chores
-- This keeps the most recent one and deletes older duplicates
-- Run this in Supabase SQL Editor

-- Delete duplicate Feed Alfred chores (keep the newest one)
DELETE FROM chores
WHERE name = 'Feed Alfred'
AND id NOT IN (
    SELECT id
    FROM chores
    WHERE name = 'Feed Alfred'
    ORDER BY created_at DESC
    LIMIT 1
);

-- Delete duplicate Feed Chevy chores (keep the newest one)
DELETE FROM chores
WHERE name = 'Feed Chevy'
AND id NOT IN (
    SELECT id
    FROM chores
    WHERE name = 'Feed Chevy'
    ORDER BY created_at DESC
    LIMIT 1
);

-- Verify - should show only one of each
SELECT name, icon, cooldown_hours, created_at
FROM chores
WHERE name IN ('Feed Alfred', 'Feed Chevy')
ORDER BY name;
