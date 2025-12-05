-- Add tiered payout system and leveling foundation
-- Run this in Supabase SQL Editor

-- 1. Add leveling fields to players table
ALTER TABLE players ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 1;
ALTER TABLE players ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;
ALTER TABLE players ADD COLUMN IF NOT EXISTS payout_tier TEXT DEFAULT 'B' CHECK (payout_tier IN ('B', 'C'));

-- 2. Create levels configuration table
CREATE TABLE IF NOT EXISTS levels (
    level_number INTEGER PRIMARY KEY,
    xp_required INTEGER NOT NULL,
    unlocks JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE levels IS 'Level progression configuration with XP requirements and unlocks';
COMMENT ON COLUMN levels.unlocks IS 'JSON field for future features (achievements, perks, etc.)';

-- 3. Insert placeholder level data (you can adjust XP values later)
INSERT INTO levels (level_number, xp_required, unlocks) VALUES
    (1, 0, '{"description": "Beginner"}'),
    (2, 1000, '{"description": "Getting Started"}'),
    (3, 2500, '{"description": "Chore Apprentice"}'),
    (4, 5000, '{"description": "Helper"}'),
    (5, 10000, '{"description": "Hard Worker"}')
ON CONFLICT (level_number) DO NOTHING;

-- 4. Create function to calculate tiered payout (Option B)
CREATE OR REPLACE FUNCTION calculate_tiered_payout(
    weekly_points INTEGER,
    player_tier TEXT DEFAULT 'B'
)
RETURNS NUMERIC AS $$
DECLARE
    payout NUMERIC := 0;
    tier1_points INTEGER;
    tier2_points INTEGER;
    tier3_points INTEGER;
BEGIN
    -- Option B: Tiered payout system
    IF player_tier = 'B' THEN
        -- Tier 1: First 500 points at $0.01 per point (max $5.00)
        tier1_points := LEAST(weekly_points, 500);
        payout := payout + (tier1_points * 0.01);

        -- Tier 2: Points 501-1000 at $0.008 per point (max $4.00)
        IF weekly_points > 500 THEN
            tier2_points := LEAST(weekly_points - 500, 500);
            payout := payout + (tier2_points * 0.008);
        END IF;

        -- Tier 3: Points 1000+ at $0.005 per point (no cap)
        IF weekly_points > 1000 THEN
            tier3_points := weekly_points - 1000;
            payout := payout + (tier3_points * 0.005);
        END IF;
    END IF;

    -- Option C will be implemented later when players reach certain level
    -- IF player_tier = 'C' THEN
    --     -- Future enhanced payout structure
    -- END IF;

    RETURN ROUND(payout, 2);
END;
$$ LANGUAGE plpgsql;

-- Add comment for documentation
COMMENT ON FUNCTION calculate_tiered_payout IS 'Calculates weekly payout based on tiered system. Option B: $0.01/pt (0-500), $0.008/pt (501-1000), $0.005/pt (1000+)';

-- 5. Create view for easy payout calculation
CREATE OR REPLACE VIEW player_weekly_payouts AS
SELECT
    p.id,
    p.name,
    p.level,
    p.xp,
    p.payout_tier,
    wt.weekly_total,
    calculate_tiered_payout(wt.weekly_total, p.payout_tier) as weekly_payout
FROM players p
CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(cc.value_awarded), 0)::INTEGER as weekly_total
    FROM chore_completions cc
    WHERE cc.player_id = p.id
        AND cc.completed_date >= DATE_TRUNC('week', CURRENT_DATE)::DATE
        AND cc.completed_date < (DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '7 days')::DATE
        AND cc.status = 'approved'
) wt;

-- Add comment
COMMENT ON VIEW player_weekly_payouts IS 'Shows current week points and calculated payout for each player';
