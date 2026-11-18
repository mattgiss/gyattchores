-- Retiring the old plaintext tables (project ukshxdoqgwoxobjdclpx), in two steps.
-- See docs/design/encrypted-relay-join.md, "Moving your family over".
--
-- Run step 1 only once every phone has moved to the relay and is on the one-app build, and the
-- old tables have stopped changing:
--   select max(created_at) from public.simple_logs;
--   select max(updated_at) from public.family_state;
-- Run step 2 only after the family has used the relay for a while and nobody needs the old data.

-- Step 1: read-only. Phones on an old build can still read, but can't write.
drop policy if exists "anon insert simple_logs" on public.simple_logs;
drop policy if exists "anon update simple_logs" on public.simple_logs;
drop policy if exists "anon insert family_state" on public.family_state;
drop policy if exists "anon update family_state" on public.family_state;

-- Step 2: delete them. Save a copy first if you want one (Table Editor → Export to CSV).
-- drop table public.simple_logs;
-- drop table public.family_state;
