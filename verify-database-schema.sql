-- Verify database schema matches app expectations

-- 1. Check all required tables exist
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND columns.table_name = tables.table_name) as column_count
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_name IN (
        'players',
        'chores',
        'chore_completions',
        'error_logs',
        'levels',
        'bonuses',
        'weekly_resets',
        'achievements',
        'player_achievements'
    )
ORDER BY table_name;

-- 2. Check chore_completions columns (this is where date filters are used)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'chore_completions'
ORDER BY ordinal_position;

-- 3. Check if get_weekly_goat function exists
SELECT
    routine_name,
    routine_type,
    data_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name = 'get_weekly_goat';

-- 4. Check RLS policies on chore_completions
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename = 'chore_completions';

-- 5. Check table permissions for anon role
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
    AND grantee = 'anon'
    AND table_name IN ('players', 'chores', 'chore_completions', 'error_logs', 'levels', 'bonuses')
ORDER BY table_name, privilege_type;
