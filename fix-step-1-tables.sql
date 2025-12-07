-- ============================================
-- STEP 1: CREATE TABLES ONLY
-- Run this FIRST, check for errors
-- ============================================

-- Create error_logs table
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type TEXT NOT NULL,
    error_message TEXT,
    player_id UUID,
    chore_id UUID,
    stack_trace TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create bonuses table
CREATE TABLE IF NOT EXISTS bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL,
    bonus_type TEXT NOT NULL,
    bonus_amount INTEGER NOT NULL DEFAULT 0,
    week_start_date DATE NOT NULL,
    description TEXT,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create weekly_resets table
CREATE TABLE IF NOT EXISTS weekly_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL UNIQUE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_resets ENABLE ROW LEVEL SECURITY;

-- Create simple policies
DROP POLICY IF EXISTS "Allow all access to error_logs" ON error_logs;
CREATE POLICY "Allow all access to error_logs" ON error_logs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all access to bonuses" ON bonuses;
CREATE POLICY "Allow all access to bonuses" ON bonuses FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all access to weekly_resets" ON weekly_resets;
CREATE POLICY "Allow all access to weekly_resets" ON weekly_resets FOR ALL USING (true) WITH CHECK (true);

-- Grant permissions
GRANT ALL ON error_logs TO authenticated, anon;
GRANT ALL ON bonuses TO authenticated, anon;
GRANT ALL ON weekly_resets TO authenticated, anon;

-- Verify
SELECT 'error_logs' as table_name, COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'error_logs'
UNION ALL
SELECT 'bonuses', COUNT(*)
FROM information_schema.columns
WHERE table_name = 'bonuses'
UNION ALL
SELECT 'weekly_resets', COUNT(*)
FROM information_schema.columns
WHERE table_name = 'weekly_resets';
