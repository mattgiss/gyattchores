-- Check the exact name of the recycling chore
SELECT id, name, description, icon, cooldown_hours
FROM chores
WHERE name ILIKE '%recycl%' OR name ILIKE '%curb%'
ORDER BY name;
