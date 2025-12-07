-- Simple version: Add all missing columns at once
-- This uses ALTER TABLE with multiple ADD COLUMN in one statement

ALTER TABLE error_logs
    ADD COLUMN IF NOT EXISTS stack_trace TEXT,
    ADD COLUMN IF NOT EXISTS logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS player_id UUID,
    ADD COLUMN IF NOT EXISTS chore_id UUID;

-- Verify columns were added
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'error_logs'
ORDER BY ordinal_position;

-- Should now show: id, error_type, error_message, stack_trace, logged_at, player_id, chore_id
