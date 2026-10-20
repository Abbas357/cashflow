-- Cash Flow: Google sign-in and the app's own background sync.
--
-- Run after 0001_init.sql. Changes:
--   * People sign in with Google. Their profile takes the name, email and
--     photo Google gives (phone stays for contact-based sharing).
--   * The app syncs directly with these tables (lib/services/cloud_sync.dart):
--     it upserts the rows changed on the device, then downloads every row
--     whose updated_at is newer than its last download. So every table gets
--     an updated_at the server stamps on each write, and an index to page
--     through it.
--   * Change history is written by the app, not a trigger. The device
--     records each change when it happens, even offline, with the values
--     before and after; a server trigger would stamp the time of upload
--     instead and log every change twice.
--   * Realtime tells signed-in devices when something changed, so they
--     download straight away.

-- ------------------------------------------------------------------ profiles

alter table public.profiles add column if not exists email text not null default '';
alter table public.profiles add column if not exists avatar_url text not null default '';

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_phone text := case when new.phone is null or new.phone = '' then null
                       else '+' || ltrim(new.phone, '+') end;
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, display_name, email, avatar_url, phone, phone_hash)
  values (
    new.id,
    coalesce(v_meta ->> 'full_name', v_meta ->> 'name', v_meta ->> 'display_name', ''),
    coalesce(new.email, ''),
    coalesce(v_meta ->> 'avatar_url', v_meta ->> 'picture', ''),
    v_phone,
    case when v_phone is null then null else public.hash_phone(v_phone) end
  )
  on conflict (id) do update
    set display_name = case when excluded.display_name = '' then profiles.display_name
                            else excluded.display_name end,
        email = excluded.email,
        avatar_url = excluded.avatar_url,
        phone = coalesce(excluded.phone, profiles.phone),
        phone_hash = coalesce(excluded.phone_hash, profiles.phone_hash),
        updated_at = now();
  return new;
end $$;

drop trigger if exists on_auth_user_saved on auth.users;
create trigger on_auth_user_saved
  after insert or update of phone, email, raw_user_meta_data on auth.users
  for each row execute function public.handle_new_user();

-- Anyone who signed up before this migration.
insert into public.profiles (id, display_name, email, avatar_url)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', ''),
       coalesce(u.email, ''),
       coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture', '')
from auth.users u
on conflict (id) do nothing;

-- The owner's member row must exist even if the profile does not yet,
-- or the owner could not see their own account.
create or replace function public.add_owner_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.account_members (account_id, user_id, role, status, display_name)
  values (
    new.id, new.owner_id, 'owner', 'active',
    coalesce((select display_name from public.profiles where id = new.owner_id), '')
  )
  on conflict (account_id, user_id) do nothing;
  return new;
end $$;

-- The app uploads with upsert (insert or update). For a new account the
-- owner's member row is only added after the insert, so the owner must be
-- able to see the account by owner_id as well.
drop policy if exists "members see the account" on public.accounts;
create policy "members see the account" on public.accounts
  for select using (owner_id = auth.uid() or public.account_role(id) is not null);

-- ---------------------------------------------------- server-stamped updates

alter table public.account_members add column if not exists updated_at timestamptz not null default now();
alter table public.entry_changes add column if not exists updated_at timestamptz not null default now();

-- clock_timestamp, not now(): rows written in one statement get distinct,
-- increasing stamps, so downloads can page through them in order.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;

drop trigger if exists accounts_touch on public.accounts;
create trigger accounts_touch
  before insert or update on public.accounts
  for each row execute function public.touch_updated_at();

drop trigger if exists account_members_touch on public.account_members;
create trigger account_members_touch
  before insert or update on public.account_members
  for each row execute function public.touch_updated_at();

drop trigger if exists entry_changes_touch on public.entry_changes;
create trigger entry_changes_touch
  before insert or update on public.entry_changes
  for each row execute function public.touch_updated_at();

create or replace function public.stamp_entry()
returns trigger language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  if tg_op = 'UPDATE' then
    new.version := greatest(new.version, old.version + 1);
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end $$;

create index if not exists accounts_sync on public.accounts (updated_at, id);
create index if not exists entries_sync on public.entries (updated_at, id);
create index if not exists entry_changes_sync on public.entry_changes (updated_at, id);
create index if not exists account_members_sync on public.account_members (updated_at, id);

-- ------------------------------------------------------------ change history

drop trigger if exists entries_log on public.entries;

create policy "editors record history" on public.entry_changes
  for insert with check (
    changed_by = auth.uid()
    and public.account_role(account_id) in ('owner', 'editor')
  );

-- ------------------------------------------------------------------ realtime

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table
        public.accounts, public.entries, public.entry_changes, public.account_members;
    exception when duplicate_object then null;
    end;
  end if;
end $$;
