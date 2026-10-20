-- Cash Flow: share an account by Gmail address or by QR code.
--
-- People sign in with Google, so the address Google verified is how they
-- are found; numbers are no longer needed (old phone invites still work).
--
--   * By email: the owner adds the person's Gmail address with a role. The
--     invitation waits until someone signs in with that address, who then
--     accepts or declines it in the app.
--   * By QR code: the owner shows a code for one account and role. Whoever
--     scans it while signed in is asked to join, and joins on Accept. A code
--     works for a day, or until the owner stops it.

-- ------------------------------------------------------------- by email

-- One invitation per number and one per address in each account; empty
-- values (an email invite has no number, and the other way round) do not
-- count.
alter table public.account_members drop constraint if exists account_members_account_id_phone_key;
create unique index if not exists account_members_phone_once
  on public.account_members (account_id, phone) where phone <> '';
create unique index if not exists account_members_email_once
  on public.account_members (account_id, lower(email)) where email <> '';

create or replace function public.my_email()
returns text language sql stable security definer set search_path = public as $$
  select lower(email) from public.profiles where id = auth.uid()
$$;

-- Whether an invitation for this number or address is for me.
create or replace function public.invite_is_mine(p_phone text, p_email text)
returns boolean language sql stable security definer set search_path = public as $$
  select (p_phone <> '' and p_phone = public.my_phone())
      or (p_email <> '' and lower(p_email) = public.my_email())
$$;

drop policy if exists "owner invites by number" on public.account_members;
create policy "owner invites by number or email" on public.account_members
  for insert with check (
    public.account_role(account_id) = 'owner'
    and role <> 'owner' and status = 'pending' and user_id is null
    and (phone ~ '^\+[1-9][0-9]{7,14}$' or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
  );

create or replace function public.my_invitations()
returns table (
  member_id uuid, account_id uuid, account_name text,
  role text, invited_by_name text, invited_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, a.id, a.name, m.role, coalesce(p.display_name, ''), m.joined_at
  from public.account_members m
  join public.accounts a on a.id = m.account_id and a.deleted_at is null
  left join public.profiles p on p.id = m.invited_by
  where m.status = 'pending' and public.invite_is_mine(m.phone, m.email)
  order by m.joined_at desc
$$;

create or replace function public.accept_invitation(p_member uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_account uuid;
begin
  select account_id into v_account from public.account_members
   where id = p_member and status = 'pending' and public.invite_is_mine(phone, email);
  if v_account is null then
    raise exception 'invitation not found';
  end if;
  -- Already in (by a QR code, say): the invitation is simply used up.
  if public.account_role(v_account) is not null then
    delete from public.account_members where id = p_member;
    return v_account;
  end if;
  update public.account_members m
     set user_id = auth.uid(),
         status = 'active',
         responded_at = now(),
         display_name = coalesce(
           nullif((select display_name from public.profiles where id = auth.uid()), ''),
           m.display_name)
   where m.id = p_member;
  return v_account;
end $$;

create or replace function public.decline_invitation(p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.account_members
     set status = 'declined', responded_at = now()
   where id = p_member and status = 'pending' and public.invite_is_mine(phone, email);
end $$;

-- ---------------------------------------------------------- by QR code

create table if not exists public.account_invites (
  id          uuid primary key default gen_random_uuid(),   -- the code in the QR
  account_id  uuid not null references public.accounts (id) on delete cascade,
  role        text not null check (role in ('editor', 'viewer')),
  created_by  uuid not null default auth.uid() references auth.users (id),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '1 day',
  stopped_at  timestamptz
);

create index if not exists account_invites_account on public.account_invites (account_id);

alter table public.account_invites enable row level security;

create policy "owner makes and stops codes" on public.account_invites
  for all using (public.account_role(account_id) = 'owner')
  with check (public.account_role(account_id) = 'owner' and created_by = auth.uid());

-- What a scanned code is for, so the app can ask before joining.
create or replace function public.invite_code_details(p_code uuid)
returns table (
  account_id uuid, account_name text, role text, invited_by_name text,
  expires_at timestamptz, usable boolean, already_member boolean
)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, i.role, coalesce(p.display_name, ''), i.expires_at,
         i.stopped_at is null and i.expires_at > now() and a.deleted_at is null,
         public.account_role(a.id) is not null
  from public.account_invites i
  join public.accounts a on a.id = i.account_id
  left join public.profiles p on p.id = i.created_by
  where i.id = p_code
$$;

-- Joins the account a code is for, with the code's role.
create or replace function public.join_with_code(p_code uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v public.account_invites%rowtype;
  v_name text;
  v_email text;
begin
  select * into v from public.account_invites where id = p_code;
  if v.id is null or v.stopped_at is not null or v.expires_at <= now() then
    raise exception 'This invitation has expired or was stopped';
  end if;
  if public.account_role(v.account_id) is not null then
    return v.account_id;
  end if;
  select display_name, email into v_name, v_email from public.profiles where id = auth.uid();
  -- An invitation by email to the same person is used up by joining.
  delete from public.account_members
   where account_id = v.account_id and status <> 'active'
     and email <> '' and lower(email) = lower(coalesce(v_email, ''));
  insert into public.account_members
    (account_id, user_id, role, status, display_name, email, invited_by, responded_at)
  values
    (v.account_id, auth.uid(), v.role, 'active', coalesce(v_name, ''), coalesce(v_email, ''),
     v.created_by, now())
  on conflict (account_id, user_id) do update
    set status = 'active', role = excluded.role, responded_at = now();
  return v.account_id;
end $$;

-- ---------------------------------------------------------- permissions

revoke execute on function public.my_email(), public.invite_is_mine(text, text)
  from public, anon, authenticated;
revoke execute on function public.invite_code_details(uuid), public.join_with_code(uuid)
  from public, anon;
grant execute on function
  public.my_invitations(),
  public.accept_invitation(uuid),
  public.decline_invitation(uuid),
  public.invite_code_details(uuid),
  public.join_with_code(uuid)
to authenticated;
