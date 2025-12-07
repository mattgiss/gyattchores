-- Debug query to check backfill entries
-- Run this to see if backfill entries are actually being inserted

-- Check all backfill entries in the last 30 days
SELECT
    cc.id,
    cc.completed_date,
    cc.completed_at,
    cc.status,
    cc.value_awarded,
    p.name as player_name,
    c.name as chore_name,
    c.icon as chore_icon
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE cc.completed_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY cc.completed_at DESC
LIMIT 50;

-- Check if there are any entries with NULL chore references
SELECT
    cc.id,
    cc.chore_id,
    cc.completed_date,
    cc.status,
    c.name as chore_name
FROM chore_completions cc
LEFT JOIN chores c ON cc.chore_id = c.id
WHERE cc.completed_date >= CURRENT_DATE - INTERVAL '30 days'
    AND c.id IS NULL;

-- Check the structure of a recent entry
SELECT
    *
FROM chore_completions
ORDER BY completed_at DESC
LIMIT 1;
