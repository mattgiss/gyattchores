-- GyattChores — shared chore-log table for cross-device sync.
--
-- Run this once in your Supabase project's SQL Editor
-- (Dashboard -> SQL Editor -> New query -> paste -> Run).
--
-- The web app (index.html) reads/writes this table with the project's
-- public anon key and no per-user login, so the RLS policies below allow
-- the anon role to read, insert, and update rows. This is a private family
-- app with non-sensitive data; do not store anything secret here.

create table if not exists public.simple_logs (
    id          uuid primary key default gen_random_uuid(),
    player_id   text        not null,
    player_name text        not null,
    chore_id    text        not null,
    chore_name  text        not null,
    chore_icon  text,
    points      integer     not null default 0,
    status      text        not null default 'pending',  -- 'pending' | 'approved' | 'rejected'
    created_at  timestamptz not null default now()
);

-- Helpful for the newest-first ordering the app uses.
create index if not exists simple_logs_created_at_idx
    on public.simple_logs (created_at desc);

-- Row Level Security: enabled, with open policies for the anon role.
alter table public.simple_logs enable row level security;

drop policy if exists "anon select simple_logs" on public.simple_logs;
drop policy if exists "anon insert simple_logs" on public.simple_logs;
drop policy if exists "anon update simple_logs" on public.simple_logs;

create policy "anon select simple_logs"
    on public.simple_logs for select
    to anon
    using (true);

create policy "anon insert simple_logs"
    on public.simple_logs for insert
    to anon
    with check (true);

create policy "anon update simple_logs"
    on public.simple_logs for update
    to anon
    using (true)
    with check (true);
