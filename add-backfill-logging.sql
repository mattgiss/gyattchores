-- Add 'backfill_entry' to admin_activity_logs activity types
-- This allows logging of backfill chore entries

-- Drop the existing constraint
ALTER TABLE admin_activity_logs
DROP CONSTRAINT IF EXISTS admin_activity_logs_activity_type_check;

-- Add the new constraint with 'backfill_entry' included
ALTER TABLE admin_activity_logs
ADD CONSTRAINT admin_activity_logs_activity_type_check
CHECK (activity_type IN ('name_change', 'avatar_change', 'player_created', 'player_deleted', 'chore_created', 'chore_deleted', 'backfill_entry', 'other'));

-- Update the comment
COMMENT ON COLUMN admin_activity_logs.activity_type IS 'Type of activity: name_change, avatar_change, player_created, player_deleted, chore_created, chore_deleted, backfill_entry, other';
