-- Cash Flow: people can delete their account themselves, as Google Play
-- requires, from the app or the web.
--
-- delete_my_account() removes the signed-in person in one transaction, so it
-- either all happens or none of it does:
--   * auth.users and auth.identities: their Google id, email, name and photo.
--   * profiles and push_devices: gone with the user (cascade).
--   * Accounts they own, with every entry, history row, member and QR code in
--     them, for everyone those accounts were shared with.
--   * Their membership of other people's accounts, and invitations addressed
--     to them.
--
-- Entries they added to accounts other people own stay, because they are part
-- of those people's books. Their name is taken off the history, which then
-- reads "Deleted user". The author columns keep the old random id, which no
-- longer leads to anyone: devices store those columns as NOT NULL, so clearing
-- them would stop every other member's sync.

-- ------------------------------------------------------------- foreign keys

-- Authors in shared books outlive the person.
alter table public.entries drop constraint if exists entries_created_by_fkey;
alter table public.entries drop constraint if exists entries_updated_by_fkey;
alter table public.entry_changes drop constraint if exists entry_changes_changed_by_fkey;

-- What the person owns goes with them, so removing a user from the Supabase
-- dashboard cannot be blocked by their books either.
alter table public.accounts drop constraint if exists accounts_owner_id_fkey;
alter table public.accounts
  add constraint accounts_owner_id_fkey
  foreign key (owner_id) references auth.users (id) on delete cascade;

alter table public.account_invites drop constraint if exists account_invites_created_by_fkey;
alter table public.account_invites
  add constraint account_invites_created_by_fkey
  foreign key (created_by) references auth.users (id) on delete cascade;

alter table public.account_members drop constraint if exists account_members_invited_by_fkey;
alter table public.account_members
  add constraint account_members_invited_by_fkey
  foreign key (invited_by) references auth.users (id) on delete set null;

-- ------------------------------------------------------------------ deleting

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_email text;
  v_phone text;
begin
  if v_me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;

  select lower(p.email), p.phone into v_email, v_phone
    from public.profiles p where p.id = v_me;

  -- Invitations to them hold their address in someone else's member list.
  delete from public.account_members m
   where m.user_id is null
     and ((coalesce(v_email, '') <> '' and lower(m.email) = v_email)
       or (coalesce(v_phone, '') <> '' and m.phone = v_phone));

  -- Stamped by its trigger, so the new name reaches the other members' devices.
  update public.entry_changes c
     set changed_by_name = 'Deleted user'
   where c.changed_by = v_me
     and exists (select 1 from public.accounts a
                  where a.id = c.account_id and a.owner_id <> v_me);

  delete from auth.users where id = v_me;
end $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
