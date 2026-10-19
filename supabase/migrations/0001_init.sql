-- Cash Flow: cloud schema for background sync and contact-based sharing.
--
-- Mirrors the device's SQLite tables (lib/data/db/app_database.dart) column
-- for column, so PowerSync can sync them without any reshaping.
--
-- Rules enforced here, not in the app:
--   * You see an account only if you are a member of it.
--   * Owners and editors write entries; viewers only read.
--   * Every insert, update and soft delete of an entry is logged with the
--     values before and after, by a trigger nobody can bypass.
--   * Accounts are shared by phone number. An invite to a number that has
--     no user yet waits, and activates when someone signs in with it.

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ profiles

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  phone        text unique,                 -- E.164, e.g. +923001234567
  phone_hash   text unique,                 -- sha256(phone), used for contact matching
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create or replace function public.hash_phone(p text)
returns text language sql immutable as $$
  select encode(extensions.digest(p, 'sha256'), 'hex')
$$;

-- Keeps phone and phone_hash in step with the verified phone on auth.users.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_phone text := case when new.phone is null or new.phone = '' then null
                       else '+' || ltrim(new.phone, '+') end;
begin
  insert into public.profiles (id, display_name, phone, phone_hash)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    v_phone,
    case when v_phone is null then null else public.hash_phone(v_phone) end
  )
  on conflict (id) do update
    set phone = excluded.phone,
        phone_hash = excluded.phone_hash,
        updated_at = now();
  return new;
end $$;

create trigger on_auth_user_saved
  after insert or update of phone on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------ accounts

create table public.accounts (
  id          uuid primary key,
  name        text not null,
  description text not null default '',
  owner_id    uuid not null references auth.users (id) default auth.uid(),
  is_shared   boolean not null default false,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.account_members (
  id           uuid primary key default gen_random_uuid(),
  account_id   uuid not null references public.accounts (id) on delete cascade,
  user_id      uuid references auth.users (id) on delete cascade,  -- null while pending
  phone        text not null default '',
  display_name text not null default '',
  email        text not null default '',
  role         text not null check (role in ('owner', 'editor', 'viewer')),
  status       text not null default 'active' check (status in ('active', 'pending')),
  invited_by   uuid references auth.users (id) default auth.uid(),
  joined_at    timestamptz not null default now(),
  unique (account_id, user_id),
  unique (account_id, phone)
);

create index account_members_user on public.account_members (user_id);
create index account_members_phone on public.account_members (phone) where status = 'pending';

-- The account's owner becomes its first member.
create or replace function public.add_owner_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.account_members (account_id, user_id, role, status, display_name)
  select new.id, new.owner_id, 'owner', 'active', p.display_name
  from public.profiles p where p.id = new.owner_id
  on conflict (account_id, user_id) do nothing;
  return new;
end $$;

create trigger accounts_add_owner
  after insert on public.accounts
  for each row execute function public.add_owner_member();

-- When someone's phone is verified, pending invites to that number become theirs.
create or replace function public.claim_invites()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.phone is not null then
    update public.account_members m
       set user_id = new.id,
           status = 'active',
           display_name = case when m.display_name = '' then new.display_name else m.display_name end
     where m.status = 'pending' and m.phone = new.phone;
  end if;
  return new;
end $$;

create trigger profiles_claim_invites
  after insert or update of phone on public.profiles
  for each row execute function public.claim_invites();

-- ------------------------------------------------------------------- entries

create table public.entries (
  id          uuid primary key,
  account_id  uuid not null references public.accounts (id) on delete cascade,
  type        text not null check (type in ('in', 'out')),
  amount      numeric(16, 2) not null check (amount >= 0),
  note        text not null default '',
  occurred_at timestamptz not null,
  attachment  text,                         -- storage path once uploaded
  transfer_id uuid,
  created_by  uuid not null references auth.users (id) default auth.uid(),
  updated_by  uuid not null references auth.users (id) default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  version     integer not null default 1
);

create index entries_account on public.entries (account_id, occurred_at);
create index entries_transfer on public.entries (transfer_id) where transfer_id is not null;

-- The server, not the client, stamps who changed what and when.
create or replace function public.stamp_entry()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  if tg_op = 'UPDATE' then
    new.version := old.version + 1;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end $$;

create trigger entries_stamp
  before insert or update on public.entries
  for each row execute function public.stamp_entry();

-- ------------------------------------------------------------ change history

create table public.entry_changes (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references public.accounts (id) on delete cascade,
  entry_id        uuid not null,
  action          text not null check (action in ('created', 'updated', 'deleted')),
  old_data        jsonb,
  new_data        jsonb,
  changed_by      uuid references auth.users (id),
  changed_by_name text not null default '',
  changed_at      timestamptz not null default now()
);

create index entry_changes_account on public.entry_changes (account_id, changed_at desc);
create index entry_changes_entry on public.entry_changes (entry_id, changed_at desc);

create or replace function public.entry_snapshot(e public.entries)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'type', e.type,
    'amount', e.amount,
    'note', e.note,
    'occurred_at', to_char(e.occurred_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  )
$$;

create or replace function public.log_entry_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_action text;
  v_old jsonb;
  v_new jsonb;
  v_name text;
begin
  select display_name into v_name from public.profiles where id = auth.uid();

  if tg_op = 'INSERT' then
    v_action := 'created';
    v_new := public.entry_snapshot(new);
  elsif new.deleted_at is not null and old.deleted_at is null then
    v_action := 'deleted';
    v_old := public.entry_snapshot(old);
  else
    v_old := public.entry_snapshot(old);
    v_new := public.entry_snapshot(new);
    if v_old = v_new then
      return new;                           -- attachment or bookkeeping only
    end if;
    v_action := 'updated';
  end if;

  insert into public.entry_changes
    (account_id, entry_id, action, old_data, new_data, changed_by, changed_by_name)
  values
    (new.account_id, new.id, v_action, v_old, v_new, auth.uid(), coalesce(v_name, ''));
  return new;
end $$;

create trigger entries_log
  after insert or update on public.entries
  for each row execute function public.log_entry_change();

-- -------------------------------------------------------------- permissions

create or replace function public.account_role(p_account uuid)
returns text language sql stable security definer set search_path = public as $$
  select role from public.account_members
  where account_id = p_account and user_id = auth.uid() and status = 'active'
$$;

alter table public.profiles        enable row level security;
alter table public.accounts        enable row level security;
alter table public.account_members enable row level security;
alter table public.entries         enable row level security;
alter table public.entry_changes   enable row level security;

create policy "own profile" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy "members see the account" on public.accounts
  for select using (public.account_role(id) is not null);
create policy "anyone creates their own account" on public.accounts
  for insert with check (owner_id = auth.uid());
create policy "owner changes the account" on public.accounts
  for update using (public.account_role(id) = 'owner');

create policy "members see each other" on public.account_members
  for select using (public.account_role(account_id) is not null);
create policy "owner invites" on public.account_members
  for insert with check (public.account_role(account_id) = 'owner' and role <> 'owner');
create policy "owner changes roles" on public.account_members
  for update using (public.account_role(account_id) = 'owner' and role <> 'owner');
create policy "owner removes, members leave" on public.account_members
  for delete using (
    role <> 'owner' and (public.account_role(account_id) = 'owner' or user_id = auth.uid())
  );

create policy "members read entries" on public.entries
  for select using (public.account_role(account_id) is not null);
create policy "editors add entries" on public.entries
  for insert with check (public.account_role(account_id) in ('owner', 'editor'));
create policy "editors change entries" on public.entries
  for update using (public.account_role(account_id) in ('owner', 'editor'));
-- No delete policy: entries are soft-deleted (deleted_at) so the change syncs.

create policy "members read history" on public.entry_changes
  for select using (public.account_role(account_id) is not null);
-- No write policies: only the trigger writes history.

-- ---------------------------------------------------------- contact matching

-- The app sends sha256 hashes of the normalised numbers in the phone's
-- contact book, never the numbers. Only hashes that belong to a user come
-- back, with that user's display name.
create or replace function public.match_contacts(phone_hashes text[])
returns table (phone_hash text, user_id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.phone_hash, p.id, p.display_name
  from public.profiles p
  where p.phone_hash = any (phone_hashes)
    and p.id <> auth.uid()
  limit 2000
$$;

revoke all on function public.match_contacts(text[]) from anon;
grant execute on function public.match_contacts(text[]) to authenticated;
