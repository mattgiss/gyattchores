-- Remove Feed Alfred chore completions from bekindhearted
-- Bekindhearted should never have gotten credit for Feed Alfred chores
-- There are 3 records that need to be deleted
-- Run this in Supabase SQL Editor

-- First, verify the records to be deleted (should show 3 records)
SELECT
    p.name as player_name,
    c.name as chore_name,
    cc.completed_date,
    cc.completed_at,
    cc.status,
    cc.value_awarded
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE p.name = 'bekindhearted'
    AND c.name = 'Feed Alfred'
ORDER BY cc.completed_at DESC;

-- Delete all Feed Alfred completions for bekindhearted
DELETE FROM chore_completions
WHERE player_id = (SELECT id FROM players WHERE name = 'bekindhearted')
    AND chore_id = (SELECT id FROM chores WHERE name = 'Feed Alfred');

-- Verify deletion (should return 0 rows)
SELECT
    p.name as player_name,
    c.name as chore_name,
    cc.completed_date,
    cc.completed_at,
    cc.status,
    cc.value_awarded
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE p.name = 'bekindhearted'
    AND c.name = 'Feed Alfred';
