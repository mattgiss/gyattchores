-- Add single_claim column to chores table
-- Single-claim chores can only be done by ONE player per cooldown period
-- (e.g., Feed Alfred - once someone feeds the dog, it's done)
-- Shared chores can be done by each player independently
-- (e.g., Wash Dishes - both kids can wash dishes separately)

ALTER TABLE chores
ADD COLUMN IF NOT EXISTS single_claim BOOLEAN DEFAULT FALSE;

-- Mark single-claim chores (only one player can do these per cooldown)
UPDATE chores SET single_claim = TRUE WHERE name IN (
    'Feed Alfred',
    'Feed Chevy',
    'Get Mail',
    'Take Out Trash',
    'Take Out Recycling',
    'Vacuum Living Room',
    'Pick up Poop',
    'Water Plants'
);

-- All other chores remain as shared (default FALSE)
-- Both players can do these independently:
-- - Clean Room (each player cleans their own room)
-- - Wash Dishes
-- - Load Dishwasher
-- - Unload Dishwasher
-- - Sweep Floor
-- - Wipe Counters
-- - Fold Laundry
-- - Set Table
-- - Clear Table
-- - Custom tasks (⭐)

COMMENT ON COLUMN chores.single_claim IS 'TRUE = only one player can complete per cooldown period; FALSE = each player can complete independently';
