-- GyattChores Row Level Security (RLS) Policies
-- Run this in Supabase SQL Editor to secure your database
--
-- IMPORTANT: Before running this, you should:
-- 1. Rotate your Supabase anon key (it was exposed in the source code)
-- 2. Consider implementing proper Supabase Auth for better security
--
-- This policy setup allows read/write access via anon key since this is a
-- family-only app without user authentication. For production app store
-- deployment, implement Supabase Auth first.

-- ============================================
-- STEP 1: Enable RLS on all tables
-- ============================================

ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE chores ENABLE ROW LEVEL SECURITY;
ALTER TABLE chore_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_resets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chore_bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- Enable RLS on levels table if it exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'levels') THEN
        EXECUTE 'ALTER TABLE levels ENABLE ROW LEVEL SECURITY';
    END IF;
END $$;

-- ============================================
-- STEP 2: Create policies for PLAYERS table
-- ============================================

-- Allow anyone to read players (needed for the app to function)
CREATE POLICY "Allow read access to players"
ON players FOR SELECT
TO anon, authenticated
USING (true);

-- Allow anyone to insert players (for now - should be admin only later)
CREATE POLICY "Allow insert access to players"
ON players FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Allow anyone to update players (for avatar/name changes)
CREATE POLICY "Allow update access to players"
ON players FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 3: Create policies for CHORES table
-- ============================================

-- Allow anyone to read chores
CREATE POLICY "Allow read access to chores"
ON chores FOR SELECT
TO anon, authenticated
USING (true);

-- Allow anyone to insert chores (admin creates custom tasks)
CREATE POLICY "Allow insert access to chores"
ON chores FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Allow anyone to update chores
CREATE POLICY "Allow update access to chores"
ON chores FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Allow anyone to delete chores (for custom task cleanup)
CREATE POLICY "Allow delete access to chores"
ON chores FOR DELETE
TO anon, authenticated
USING (true);

-- ============================================
-- STEP 4: Create policies for CHORE_COMPLETIONS table
-- ============================================

-- Allow anyone to read completions
CREATE POLICY "Allow read access to chore_completions"
ON chore_completions FOR SELECT
TO anon, authenticated
USING (true);

-- Allow anyone to insert completions
CREATE POLICY "Allow insert access to chore_completions"
ON chore_completions FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Allow anyone to update completions (for approval/rejection)
CREATE POLICY "Allow update access to chore_completions"
ON chore_completions FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Allow anyone to delete completions (for admin cleanup)
CREATE POLICY "Allow delete access to chore_completions"
ON chore_completions FOR DELETE
TO anon, authenticated
USING (true);

-- ============================================
-- STEP 5: Create policies for WEEKLY_RESETS table
-- ============================================

CREATE POLICY "Allow read access to weekly_resets"
ON weekly_resets FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to weekly_resets"
ON weekly_resets FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- ============================================
-- STEP 6: Create policies for BONUSES table
-- ============================================

CREATE POLICY "Allow read access to bonuses"
ON bonuses FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to bonuses"
ON bonuses FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- ============================================
-- STEP 7: Create policies for ACHIEVEMENTS table
-- ============================================

CREATE POLICY "Allow read access to achievements"
ON achievements FOR SELECT
TO anon, authenticated
USING (true);

-- Achievements are system-defined, no insert/update/delete needed

-- ============================================
-- STEP 8: Create policies for PLAYER_ACHIEVEMENTS table
-- ============================================

CREATE POLICY "Allow read access to player_achievements"
ON player_achievements FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to player_achievements"
ON player_achievements FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "Allow update access to player_achievements"
ON player_achievements FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 9: Create policies for PLAYER_STATS table
-- ============================================

CREATE POLICY "Allow read access to player_stats"
ON player_stats FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to player_stats"
ON player_stats FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "Allow update access to player_stats"
ON player_stats FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 10: Create policies for CHORE_BIDS table
-- ============================================

CREATE POLICY "Allow read access to chore_bids"
ON chore_bids FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to chore_bids"
ON chore_bids FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "Allow update access to chore_bids"
ON chore_bids FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 11: Create policies for ADMIN_ACTIVITY_LOGS table
-- ============================================

CREATE POLICY "Allow read access to admin_activity_logs"
ON admin_activity_logs FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to admin_activity_logs"
ON admin_activity_logs FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- ============================================
-- STEP 12: Create policies for ERROR_LOGS table
-- ============================================

CREATE POLICY "Allow read access to error_logs"
ON error_logs FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Allow insert access to error_logs"
ON error_logs FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- ============================================
-- STEP 13: Create policies for LEVELS table (if exists)
-- ============================================

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'levels') THEN
        EXECUTE 'CREATE POLICY "Allow read access to levels" ON levels FOR SELECT TO anon, authenticated USING (true)';
    END IF;
END $$;

-- ============================================
-- VERIFICATION: Check RLS is enabled
-- ============================================

-- Run this query to verify RLS is enabled on all tables:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';

-- ============================================
-- NOTES FOR APP STORE DEPLOYMENT
-- ============================================
--
-- The current RLS setup allows full access via the anon key, which is still
-- a security risk if the key is exposed. For app store deployment:
--
-- 1. ROTATE YOUR ANON KEY:
--    - Go to Supabase Dashboard > Settings > API
--    - Click "Generate new anon key"
--    - Update your index.html with the new key
--    - The old key will be invalidated
--
-- 2. IMPLEMENT SUPABASE AUTH:
--    - Add user authentication (email/password, or magic link)
--    - Create an "admin" role for parents
--    - Create a "player" role for kids
--    - Update policies to check auth.uid() and user roles
--
-- 3. EXAMPLE OF STRICTER POLICIES (for after implementing auth):
--
--    -- Only allow admins to approve chores:
--    CREATE POLICY "Only admins can update chore status"
--    ON chore_completions FOR UPDATE
--    USING (
--        auth.jwt() ->> 'role' = 'admin'
--        OR (status = 'pending' AND player_id = auth.uid())
--    );
--
--    -- Only allow players to see their own stats:
--    CREATE POLICY "Players see own stats"
--    ON player_stats FOR SELECT
--    USING (
--        auth.jwt() ->> 'role' = 'admin'
--        OR player_id = auth.uid()
--    );
