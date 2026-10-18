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
