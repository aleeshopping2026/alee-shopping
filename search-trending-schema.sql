-- Run once in Supabase SQL Editor to share product search trends across visitors.
-- Only product IDs are stored; search text and customer details are not collected.
create table if not exists public.product_search_events (
  event_id uuid primary key default gen_random_uuid(),
  product_id integer not null check (product_id > 0),
  searched_at timestamptz not null default now()
);

alter table public.product_search_events enable row level security;
drop policy if exists "Visitors can record product search events" on public.product_search_events;
create policy "Visitors can record product search events"
  on public.product_search_events for insert to anon, authenticated
  with check (product_id > 0);

grant insert on public.product_search_events to anon, authenticated;

create index if not exists product_search_events_recent_idx
  on public.product_search_events(searched_at desc, product_id);

create or replace function public.get_product_search_trends()
returns table(product_id integer, search_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select event.product_id, count(*)::bigint as search_count
  from public.product_search_events as event
  where event.searched_at >= now() - interval '30 days'
  group by event.product_id
  order by count(*) desc, event.product_id
  limit 100;
$$;

revoke all on function public.get_product_search_trends() from public;
grant execute on function public.get_product_search_trends() to anon, authenticated;

-- Store per-account product IDs only (never the words people type).
create table if not exists public.product_user_search_events (
  event_id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id integer not null check (product_id > 0),
  event_type text not null default 'search' check (event_type in ('search','view')),
  searched_at timestamptz not null default now()
);

alter table public.product_user_search_events
  add column if not exists event_type text not null default 'search';
alter table public.product_user_search_events
  drop constraint if exists product_user_search_events_event_type_check;
alter table public.product_user_search_events
  add constraint product_user_search_events_event_type_check check (event_type in ('search','view'));

alter table public.product_user_search_events enable row level security;
drop policy if exists "Users can record their own product searches" on public.product_user_search_events;
create policy "Users can record their own product searches"
  on public.product_user_search_events for insert to authenticated
  with check (user_id = auth.uid());

create index if not exists product_user_search_events_recent_idx
  on public.product_user_search_events(user_id, searched_at desc, product_id);

create or replace function public.get_my_product_recommendations()
returns table(product_id integer, search_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select event.product_id,
         sum(case when event.event_type = 'view' then 5 else 1 end)::bigint as search_count
  from public.product_user_search_events as event
  where event.user_id = auth.uid()
    and event.searched_at >= now() - interval '90 days'
  group by event.product_id
  order by sum(case when event.event_type = 'view' then 5 else 1 end) desc,
           max(case when event.event_type = 'view' then event.searched_at end) desc nulls last,
           max(event.searched_at) desc,
           event.product_id
  limit 50;
$$;

revoke all on function public.get_my_product_recommendations() from public, anon;
grant execute on function public.get_my_product_recommendations() to authenticated;
grant insert on public.product_user_search_events to authenticated;

create or replace function public.get_my_recent_product_views()
returns table(product_id integer, viewed_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select recent.product_id, recent.viewed_at
  from (
    select distinct on (event.product_id)
      event.product_id, event.searched_at as viewed_at
    from public.product_user_search_events as event
    where event.user_id = auth.uid()
      and event.event_type = 'view'
      and event.searched_at >= now() - interval '90 days'
    order by event.product_id, event.searched_at desc
  ) as recent
  order by recent.viewed_at desc
  limit 60;
$$;

revoke all on function public.get_my_recent_product_views() from public, anon;
grant execute on function public.get_my_recent_product_views() to authenticated;

-- Anonymous, site-wide search terms power the Trending Searches chips.
-- Only submitted terms are stored; this table contains no account or contact fields.
create table if not exists public.search_term_events (
  event_id uuid primary key default gen_random_uuid(),
  search_term text not null check (char_length(btrim(search_term)) between 2 and 80),
  searched_at timestamptz not null default now()
);

alter table public.search_term_events enable row level security;
drop policy if exists "Visitors can record search terms" on public.search_term_events;
create policy "Visitors can record search terms"
  on public.search_term_events for insert to anon, authenticated
  with check (
    char_length(btrim(search_term)) between 2 and 80
    and search_term !~ '[[:cntrl:]]'
  );

grant insert on public.search_term_events to anon, authenticated;

create index if not exists search_term_events_recent_idx
  on public.search_term_events(searched_at desc);

create or replace function public.get_trending_search_terms(
  p_days integer default 30,
  p_limit integer default 12
)
returns table(search_term text, search_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  with normalized_terms as (
    select
      regexp_replace(lower(btrim(event.search_term)), '\s+', ' ', 'g') as normalized_term,
      btrim(event.search_term) as display_term
    from public.search_term_events as event
    where event.searched_at >= now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 90))
  ), aggregated_terms as (
    select normalized_term, min(display_term) as display_term, count(*)::bigint as search_count
    from normalized_terms
    group by normalized_term
  )
  select aggregated_terms.display_term, aggregated_terms.search_count
  from aggregated_terms
  order by aggregated_terms.search_count desc, aggregated_terms.display_term asc
  limit least(greatest(coalesce(p_limit, 12), 1), 20);
$$;

revoke all on function public.get_trending_search_terms(integer, integer) from public;
grant execute on function public.get_trending_search_terms(integer, integer) to anon, authenticated;
