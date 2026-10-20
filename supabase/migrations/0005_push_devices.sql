-- Cash Flow: phones that get push notifications (Firebase Cloud Messaging).
--
-- Each signed-in phone registers its Firebase token here. When someone
-- uploads a change to a shared account, the app calls the notify-changes
-- Edge Function, which pushes it to every other member's phones.

create table if not exists public.push_devices (
  token      text primary key,              -- Firebase registration token
  user_id    uuid not null references auth.users (id) on delete cascade,
  platform   text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists push_devices_user on public.push_devices (user_id);

alter table public.push_devices enable row level security;

create policy "own devices" on public.push_devices
  for select using (user_id = auth.uid());

-- A phone signed in to another account before passes to whoever signs in
-- on it now, so these go through functions rather than plain writes.
create or replace function public.register_push_device(p_token text, p_platform text default 'android')
returns void language sql security definer set search_path = public as $$
  insert into public.push_devices (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = auth.uid(), platform = excluded.platform, updated_at = now()
$$;

create or replace function public.unregister_push_device(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_devices where token = p_token and user_id = auth.uid()
$$;

revoke execute on function public.register_push_device(text, text), public.unregister_push_device(text)
  from public, anon;
grant execute on function public.register_push_device(text, text), public.unregister_push_device(text)
  to authenticated;
