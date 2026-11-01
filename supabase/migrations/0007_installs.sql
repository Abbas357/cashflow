-- Cash Flow: how many people use the app in each country.
--
-- One row per install, signed in or not, holding a random id that is not tied
-- to any account, the country, the currency and the platform. No name, email
-- or entries. Reinstalling, or using another device or browser, counts as a
-- new install.
--
-- Nobody can read this table through the app's API: it has no policies. Count
-- from the Supabase dashboard's SQL editor:
--
--   select country, count(*) as installs
--     from public.installs
--    group by country
--    order by installs desc;

create table if not exists public.installs (
  id         uuid primary key,
  country    text check (country ~ '^[A-Z]{2}$'),   -- null when it could not be detected
  currency   text check (currency ~ '^[A-Z]{3}$'),
  platform   text not null check (platform ~ '^[a-z]{2,16}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists installs_country on public.installs (country);

alter table public.installs enable row level security;
revoke all on public.installs from public, anon, authenticated;

-- People who never signed in report too, so anon may call this. It can only
-- add or update one row, by an id that only that install knows.
create or replace function public.report_install(
  p_id uuid,
  p_country text,
  p_currency text,
  p_platform text
)
returns void language sql security definer set search_path = '' as $$
  insert into public.installs (id, country, currency, platform)
  values (p_id, p_country, p_currency, p_platform)
  on conflict (id) do update
    set country = excluded.country,
        currency = excluded.currency,
        platform = excluded.platform,
        updated_at = now()
$$;

revoke execute on function public.report_install(uuid, text, text, text) from public;
grant execute on function public.report_install(uuid, text, text, text) to anon, authenticated;
