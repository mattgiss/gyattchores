-- GyattChores — parents' hidden daily picks, synced between the native apps.
--
-- Run this once in your Supabase project's SQL Editor
-- (Dashboard -> SQL Editor -> New query -> paste -> Run).
--
-- One row per kid per day. A chore a kid submits that is in chore_ids earns
-- double points. Like simple_logs, the native apps use the public anon key
-- with no per-user login, so the policies below let the anon role read,
-- insert and update. "Hidden" means the kid's screen doesn't show the picks;
-- the kid's phone still downloads them so it can score a match.

create table if not exists public.parent_picks (
    player_id  text        not null,
    day        date        not null,
    chore_ids  text[]      not null default '{}',
    updated_at timestamptz not null default now(),
    primary key (player_id, day)
);

alter table public.parent_picks enable row level security;

drop policy if exists "anon select parent_picks" on public.parent_picks;
drop policy if exists "anon insert parent_picks" on public.parent_picks;
drop policy if exists "anon update parent_picks" on public.parent_picks;

create policy "anon select parent_picks"
    on public.parent_picks for select
    to anon
    using (true);

create policy "anon insert parent_picks"
    on public.parent_picks for insert
    to anon
    with check (true);

create policy "anon update parent_picks"
    on public.parent_picks for update
    to anon
    using (true)
    with check (true);
