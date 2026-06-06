-- GyattChores — Supabase Data Audit
-- Run these in the Supabase SQL Editor: https://supabase.com/dashboard/project/ukshxdoqgwoxobjdclpx/sql
-- Run each section individually and share results with Claude to complete the data analysis.

-- ─────────────────────────────────────────────────────────────
-- 1. OVERVIEW: total records by status
-- ─────────────────────────────────────────────────────────────
SELECT
    status,
    COUNT(*)                          AS count,
    SUM(points)                       AS total_points,
    MIN(created_at)                   AS earliest,
    MAX(created_at)                   AS latest
FROM simple_logs
GROUP BY status
ORDER BY count DESC;

-- ─────────────────────────────────────────────────────────────
-- 2. PER-PLAYER BREAKDOWN (all time)
-- ─────────────────────────────────────────────────────────────
SELECT
    player_name,
    status,
    COUNT(*)                          AS chores,
    SUM(points)                       AS points
FROM simple_logs
GROUP BY player_name, status
ORDER BY player_name, status;

-- ─────────────────────────────────────────────────────────────
-- 3. WEEKLY ACTIVITY (approved chores, last 12 weeks)
-- Shows any gaps in logging — a gap > 1 week may indicate data loss
-- ─────────────────────────────────────────────────────────────
SELECT
    DATE_TRUNC('week', created_at)    AS week_of,
    player_name,
    COUNT(*)                          AS chores_approved,
    SUM(points)                       AS points_earned
FROM simple_logs
WHERE status = 'approved'
  AND created_at >= NOW() - INTERVAL '12 weeks'
GROUP BY week_of, player_name
ORDER BY week_of DESC, player_name;

-- ─────────────────────────────────────────────────────────────
-- 4. DATA GAPS — weeks with zero activity (any player)
-- A gap here means either no chores were done, the app was down,
-- or data was logged locally but never synced
-- ─────────────────────────────────────────────────────────────
WITH weeks AS (
    SELECT generate_series(
        DATE_TRUNC('week', MIN(created_at)),
        DATE_TRUNC('week', NOW()),
        '1 week'::interval
    ) AS week_of
    FROM simple_logs
),
activity AS (
    SELECT DATE_TRUNC('week', created_at) AS week_of, COUNT(*) AS count
    FROM simple_logs
    WHERE status = 'approved'
    GROUP BY DATE_TRUNC('week', created_at)
)
SELECT
    w.week_of,
    COALESCE(a.count, 0)              AS approved_chores,
    CASE WHEN a.count IS NULL THEN '⚠️  GAP — no approved chores' ELSE '✅' END AS health
FROM weeks w
LEFT JOIN activity a ON a.week_of = w.week_of
ORDER BY w.week_of DESC;

-- ─────────────────────────────────────────────────────────────
-- 5. STALE PENDING — logs stuck awaiting approval for > 24h
-- These are likely orphaned (device that logged them is offline,
-- or the approval screen was missed)
-- ─────────────────────────────────────────────────────────────
SELECT
    id,
    player_name,
    chore_name,
    points,
    created_at,
    NOW() - created_at                AS age
FROM simple_logs
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '24 hours'
ORDER BY created_at ASC;

-- ─────────────────────────────────────────────────────────────
-- 6. DUPLICATE DETECTION
-- Same player + same chore within 5 minutes may be double-taps
-- ─────────────────────────────────────────────────────────────
SELECT
    a.id          AS id_1,
    b.id          AS id_2,
    a.player_name,
    a.chore_name,
    a.created_at  AS time_1,
    b.created_at  AS time_2,
    b.created_at - a.created_at AS gap
FROM simple_logs a
JOIN simple_logs b
    ON  a.player_name = b.player_name
    AND a.chore_name  = b.chore_name
    AND b.created_at  > a.created_at
    AND b.created_at  < a.created_at + INTERVAL '5 minutes'
    AND a.id < b.id
ORDER BY a.created_at DESC;

-- ─────────────────────────────────────────────────────────────
-- 7. CLEANUP — reject all stale pending logs (> 7 days old)
-- Run ONLY after reviewing query 5 above and confirming they're orphaned
-- ─────────────────────────────────────────────────────────────
-- UPDATE simple_logs
-- SET status = 'rejected'
-- WHERE status = 'pending'
--   AND created_at < NOW() - INTERVAL '7 days';

-- ─────────────────────────────────────────────────────────────
-- 8. CLEANUP — delete confirmed duplicate double-taps
-- Replace <id_to_delete> with the id_2 values from query 6
-- ─────────────────────────────────────────────────────────────
-- DELETE FROM simple_logs WHERE id IN ('<id_to_delete>', ...);

-- ─────────────────────────────────────────────────────────────
-- 9. ALL-TIME LEADERBOARD
-- ─────────────────────────────────────────────────────────────
SELECT
    player_name,
    COUNT(*)                          AS total_chores,
    SUM(points)                       AS total_points,
    ROUND(AVG(points), 0)             AS avg_points_per_chore,
    MAX(created_at)                   AS last_active
FROM simple_logs
WHERE status = 'approved'
GROUP BY player_name
ORDER BY total_points DESC;

-- ─────────────────────────────────────────────────────────────
-- 10. MOST POPULAR CHORES
-- ─────────────────────────────────────────────────────────────
SELECT
    chore_name,
    chore_icon,
    points,
    COUNT(*)                          AS times_completed,
    COUNT(*) * points                 AS total_points_earned
FROM simple_logs
WHERE status = 'approved'
GROUP BY chore_name, chore_icon, points
ORDER BY times_completed DESC;
