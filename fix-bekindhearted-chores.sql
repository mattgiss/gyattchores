-- Fix bekindhearted's chore history to only include Feed Chevy
-- This removes any Feed Alfred completions from bekindhearted

-- First, let's see what we're working with
SELECT
    p.name as player_name,
    c.name as chore_name,
    cc.completed_at,
    cc.status,
    cc.value_awarded
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE p.name = 'bekindhearted'
    AND c.name IN ('Feed Alfred', 'Feed Chevy')
ORDER BY cc.completed_at DESC;

-- Delete Feed Alfred completions for bekindhearted
DELETE FROM chore_completions
WHERE player_id = (SELECT id FROM players WHERE name = 'bekindhearted')
    AND chore_id = (SELECT id FROM chores WHERE name = 'Feed Alfred');

-- Verify the fix
SELECT
    p.name as player_name,
    c.name as chore_name,
    cc.completed_at,
    cc.status,
    cc.value_awarded
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE p.name = 'bekindhearted'
    AND c.name IN ('Feed Alfred', 'Feed Chevy')
ORDER BY cc.completed_at DESC;
