-- Check what columns currently exist in error_logs table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'error_logs'
ORDER BY ordinal_position;
