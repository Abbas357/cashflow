-- Cash Flow: people can delete what their install reported (0007_installs.sql),
-- from Settings in the app. Allowed signed out too, since reporting is, and it
-- only touches the one row whose random id that install holds.

create or replace function public.delete_install(p_id uuid)
returns void language sql security definer set search_path = '' as $$
  delete from public.installs where id = p_id
$$;

revoke execute on function public.delete_install(uuid) from public;
grant execute on function public.delete_install(uuid) to anon, authenticated;
