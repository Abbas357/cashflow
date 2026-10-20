-- Cash Flow: tighten who may call the database functions (from the
-- Supabase security advisor).
--
--   * Functions get a fixed search_path, so a caller cannot swap in tables
--     or functions of the same name.
--   * Nobody signed out can call any of them. Trigger functions are not
--     callable through the API at all; the ones the app or the access
--     rules use are callable only when signed in.
--   * log_entry_change() is gone: history comes from the app (0002).

drop function if exists public.log_entry_change();

alter function public.hash_phone(text) set search_path = '';
alter function public.entry_snapshot(public.entries) set search_path = '';
alter function public.stamp_entry() set search_path = '';
alter function public.touch_updated_at() set search_path = '';

revoke execute on function
  public.handle_new_user(),
  public.add_owner_member(),
  public.stamp_entry(),
  public.touch_updated_at()
from public, anon, authenticated;

revoke execute on function
  public.account_role(uuid),
  public.my_phone(),
  public.my_invitations(),
  public.accept_invitation(uuid),
  public.decline_invitation(uuid),
  public.match_contacts(text[]),
  public.hash_phone(text),
  public.entry_snapshot(public.entries)
from public, anon;

-- account_role() is evaluated inside the row level security rules, as the
-- signed-in user, so they must be able to run it.
grant execute on function
  public.account_role(uuid),
  public.my_phone(),
  public.my_invitations(),
  public.accept_invitation(uuid),
  public.decline_invitation(uuid),
  public.match_contacts(text[])
to authenticated;
