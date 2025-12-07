-- Add Chore Bidding System
-- Players can propose custom tasks that admins can accept or counter-bid

-- Create chore_bids table
CREATE TABLE IF NOT EXISTS chore_bids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    chore_name TEXT NOT NULL,
    proposed_points INTEGER NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'counter_offered', 'completed')),
    admin_counter_points INTEGER,
    admin_notes TEXT,
    due_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add assigned_player_id to chores table to make tasks player-specific
ALTER TABLE chores
ADD COLUMN IF NOT EXISTS assigned_player_id UUID REFERENCES players(id) ON DELETE CASCADE;

-- Add is_from_bid flag to track chores created from accepted bids
ALTER TABLE chores
ADD COLUMN IF NOT EXISTS is_from_bid BOOLEAN DEFAULT FALSE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_chore_bids_player ON chore_bids(player_id);
CREATE INDEX IF NOT EXISTS idx_chore_bids_status ON chore_bids(status);
CREATE INDEX IF NOT EXISTS idx_chores_assigned_player ON chores(assigned_player_id);

-- Comments for documentation
COMMENT ON TABLE chore_bids IS 'Player-proposed custom tasks awaiting admin review';
COMMENT ON COLUMN chores.assigned_player_id IS 'If set, this chore is only available to this specific player';
COMMENT ON COLUMN chores.is_from_bid IS 'True if this chore was created from an accepted player bid';
