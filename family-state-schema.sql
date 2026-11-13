-- GyattChores — small lists shared between the family's phones (native apps).
--
-- Run this once in your Supabase project's SQL Editor
-- (Dashboard -> SQL Editor -> New query -> paste -> Run).
--
-- One row per named list. The newest write wins (updated_at).
--   dare|<fromPlayerId>|<yyyy-MM-dd>   that person's dares for that day, as "targetPlayerId:choreId"
--   players                            the player list, as "id:name"
--   removed_players                    ids of removed players
--
-- Like simple_logs, the apps use the public anon key with no per-user login, so
-- the policies below let the anon role read, insert and update. Dares are hidden
-- in the app until the next day, but every phone downloads them: this keeps a
-- family game honest, it is not real secrecy.

create table if not exists public.family_state (
    key        text        primary key,
    items      text[]      not null default '{}',
    updated_at timestamptz not null default now()
);

alter table public.family_state enable row level security;

drop policy if exists "anon select family_state" on public.family_state;
drop policy if exists "anon insert family_state" on public.family_state;
drop policy if exists "anon update family_state" on public.family_state;

create policy "anon select family_state"
    on public.family_state for select
    to anon
    using (true);

create policy "anon insert family_state"
    on public.family_state for insert
    to anon
    with check (true);

create policy "anon update family_state"
    on public.family_state for update
    to anon
    using (true)
    with check (true);
