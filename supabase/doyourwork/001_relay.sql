-- DOYOURWORK relay: families on more than one phone (docs/design/encrypted-relay-join.md).
--
-- For the DOYOURWORK Supabase project only, not the old project that holds simple_logs and
-- family_state. Run once in that project's SQL Editor. Also turn on
-- Authentication -> Sign In / Providers -> "Allow anonymous sign-ins".
--
-- The server never sees family data in the clear. Phones encrypt every record with a family key
-- that passes between phones by QR code and is never sent here. What the server holds: household
-- ids, which anonymous devices belong to each household, hashed one-time join tokens, and
-- ciphertext with timestamps.
--
-- Phones never write these tables directly except `records`. Everything else goes through the
-- functions at the bottom, which check membership.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------------------------
-- Tables

create table public.households (
    id         uuid        primary key,              -- made on the phone; also in the QR code
    created_at timestamptz not null default now()
);

create table public.household_devices (
    household_id uuid        not null references public.households (id) on delete cascade,
    user_id      uuid        not null references auth.users (id) on delete cascade,
    joined_at    timestamptz not null default now(),
    primary key (household_id, user_id)
);
create index household_devices_user_idx on public.household_devices (user_id);

create table public.join_tokens (
    token_hash   bytea       primary key,            -- sha256 of the token in the QR code
    household_id uuid        not null references public.households (id) on delete cascade,
    created_by   uuid        not null,
    expires_at   timestamptz not null,
    used_at      timestamptz
);

-- One row per chore log (kind 'log', row_id = the log's id) or per piece of shared state
-- (kind 'state', row_id = HMAC of the state key under the family key, so names like
-- "dare|3|2026-11-16" don't show here).
create table public.records (
    household_id      uuid        not null references public.households (id) on delete cascade,
    kind              text        not null check (kind in ('log', 'state')),
    row_id            text        not null check (length(row_id) between 1 and 128),
    ciphertext        text        not null check (length(ciphertext) <= 87400),  -- base64, about 64 KB
    client_updated_at bigint      not null,          -- ms since 1970, from the phone; merging uses it
    server_updated_at timestamptz not null default clock_timestamp(),
    primary key (household_id, kind, row_id)
);
-- Phones fetch "everything changed since my last fetch, minus a minute", so a write that commits
-- late with an earlier timestamp is still picked up; merging the same record twice is harmless.
create index records_changed_idx on public.records (household_id, server_updated_at);

create function public.records_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
    new.server_updated_at := clock_timestamp();
    return new;
end $$;

create trigger records_touch before insert or update on public.records
    for each row execute function public.records_touch();

-- ---------------------------------------------------------------------------------------------
-- Who may see what

create function public.is_member(h uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (
        select 1 from public.household_devices d
        where d.household_id = h and d.user_id = auth.uid()
    )
$$;

alter table public.households        enable row level security;
alter table public.household_devices enable row level security;
alter table public.join_tokens       enable row level security;
alter table public.records           enable row level security;

-- Signed-out callers get nothing at all.
revoke all on public.households, public.household_devices, public.join_tokens, public.records from anon;
-- Signed-in devices (anonymous sign-ins use the authenticated role): reads, plus writes to records.
revoke all on public.households, public.household_devices, public.join_tokens, public.records from authenticated;
grant select on public.households, public.household_devices to authenticated;
grant select, insert, update on public.records to authenticated;

create policy "members see their household" on public.households
    for select to authenticated using (public.is_member(id));

create policy "members see their household's devices" on public.household_devices
    for select to authenticated using (public.is_member(household_id));

-- join_tokens: no policies, so no direct access; only the functions below touch it.

create policy "members read records" on public.records
    for select to authenticated using (public.is_member(household_id));

create policy "members add records" on public.records
    for insert to authenticated with check (public.is_member(household_id));

create policy "members change records" on public.records
    for update to authenticated
    using (public.is_member(household_id)) with check (public.is_member(household_id));

-- ---------------------------------------------------------------------------------------------
-- Functions the apps call (POST /rest/v1/rpc/<name>)

-- The first "Add a phone" on a family's first phone: makes the household with this device in it.
create function public.create_household(p_household uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
    insert into public.households (id) values (p_household);
    insert into public.household_devices (household_id, user_id) values (p_household, auth.uid());
end $$;

-- "Add a phone": the phone makes a random token, puts it in the QR code, and sends only its hash.
create function public.create_join_token(p_household uuid, p_token_hash bytea) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
    expires timestamptz := now() + interval '10 minutes';
begin
    if not public.is_member(p_household) then raise exception 'not a member' using errcode = '42501'; end if;
    if length(p_token_hash) <> 32 then raise exception 'bad token hash' using errcode = '22023'; end if;
    delete from public.join_tokens where household_id = p_household and (expires_at < now() or used_at is not null);
    insert into public.join_tokens (token_hash, household_id, created_by, expires_at)
        values (p_token_hash, p_household, auth.uid(), expires);
    return expires;
end $$;

-- The scanning phone: sends the token from the QR code. True if it's now in the household.
create function public.join_household(p_household uuid, p_token bytea) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
    hit public.join_tokens;
begin
    if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
    select * into hit from public.join_tokens
        where token_hash = extensions.digest(p_token, 'sha256')
          and household_id = p_household
          and used_at is null
          and expires_at > now()
        for update;
    if not found then return false; end if;
    update public.join_tokens set used_at = now() where token_hash = hit.token_hash;
    insert into public.household_devices (household_id, user_id) values (p_household, auth.uid())
        on conflict do nothing;
    return true;
end $$;

-- Admin -> Phones -> Remove (or a phone leaving by itself, with its own user id).
create function public.remove_device(p_household uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if not public.is_member(p_household) then raise exception 'not a member' using errcode = '42501'; end if;
    delete from public.household_devices where household_id = p_household and user_id = p_user;
end $$;

-- Admin -> "Delete this family from the server": the household and every record go.
create function public.delete_household(p_household uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if not public.is_member(p_household) then raise exception 'not a member' using errcode = '42501'; end if;
    delete from public.households where id = p_household;
end $$;

revoke execute on function
    public.is_member(uuid),
    public.create_household(uuid),
    public.create_join_token(uuid, bytea),
    public.join_household(uuid, bytea),
    public.remove_device(uuid, uuid),
    public.delete_household(uuid)
from public, anon;

grant execute on function
    public.is_member(uuid),
    public.create_household(uuid),
    public.create_join_token(uuid, bytea),
    public.join_household(uuid, bytea),
    public.remove_device(uuid, uuid),
    public.delete_household(uuid)
to authenticated;
