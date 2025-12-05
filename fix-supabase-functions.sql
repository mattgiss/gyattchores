-- Fix search_path warnings for all functions
ALTER FUNCTION public.get_error_stats() SET search_path = public;
ALTER FUNCTION public.get_weekly_totals(DATE) SET search_path = public;
ALTER FUNCTION public.get_weekly_goat() SET search_path = public;
ALTER FUNCTION public.get_current_week_start() SET search_path = public;
ALTER FUNCTION public.get_recent_error_logs(INTEGER, TEXT) SET search_path = public;
ALTER FUNCTION public.calculate_tiered_payout(INTEGER, TEXT) SET search_path = public;

-- Verify all functions exist
SELECT
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name IN (
        'get_error_stats',å
        'get_weekly_totals',
        'get_weekly_goat',
        'get_current_week_start',
        'get_recent_error_logs',
        'calculate_tiered_payout'
    )
ORDER BY routine_name;

-- Check if all required tables exist
SELECT table_name
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

-- Check for RLS policies that might be blocking access
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
