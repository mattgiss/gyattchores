-- Check if Feed Chevy chore exists and is active
SELECT id, name, icon, base_value, cooldown_hours, is_active, created_at
FROM chores
WHERE name ILIKE '%chevy%'
ORDER BY created_at DESC;

-- Check recent completions of Feed Chevy by all players
SELECT
    cc.id,
    cc.player_id,
    p.name as player_name,
    cc.completed_at,
    cc.status,
    c.name as chore_name,
    c.cooldown_hours
FROM chore_completions cc
JOIN players p ON cc.player_id = p.id
JOIN chores c ON cc.chore_id = c.id
WHERE c.name ILIKE '%chevy%'
    AND cc.completed_at >= NOW() - INTERVAL '7 days'
ORDER BY cc.completed_at DESC;
