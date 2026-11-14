-- ALEE product recommendations, exploration exposure, product ratings, and sponsored slots.
-- Run once in Supabase SQL Editor. This project already uses Supabase/Postgres as its backend.

-- Seller products get a simple delivery estimate so ranking can distinguish fast delivery.
alter table public.seller_products
  add column if not exists delivery_days smallint;
do $$ begin
  alter table public.seller_products add constraint seller_products_delivery_days_check
    check (delivery_days is null or delivery_days between 1 and 30);
exception when duplicate_object then null; end $$;

-- Keep the public product view's existing columns and append delivery_days.
create or replace view public.seller_products_profile_public
with (security_barrier = true)
as
select p.id, p.shop_id, p.name, p.price, p.category, p.category_label, p.description,
       p.features, p.sizes, p.image_urls, p.created_at, p.wholesale_price,
       p.offer_price, p.stock, p.condition, p.colors,
       coalesce(s.currency_code, 'LKR') as currency_code,
       p.free_shipping,
       coalesce((
         select sum(case
           when item.value->>'quantity' ~ '^[0-9]+$' then (item.value->>'quantity')::bigint
           else 1::bigint
         end)
         from public.store_orders o
         cross join lateral jsonb_array_elements(o.items) as item(value)
         where o.shop_id = p.shop_id
           and o.status <> 'cancelled'
           and item.value->>'product_id' = p.id::text
       ), 0)::bigint as sold_count,
       p.delivery_days
from public.seller_products p
join public.seller_shops s on s.id = p.shop_id;
grant select on public.seller_products_profile_public to anon, authenticated;

-- Ratings are optional on existing comments. New ratings are 1–5 stars.
alter table public.product_reviews add column if not exists rating smallint;
do $$ begin
  alter table public.product_reviews add constraint product_reviews_rating_check
    check (rating is null or rating between 1 and 5);
exception when duplicate_object then null; end $$;

create table if not exists public.product_recommendation_events (
  event_id bigint generated always as identity primary key,
  product_id bigint not null check (product_id > 0),
  user_id uuid references auth.users(id) on delete cascade,
  visitor_id uuid,
  action text not null check (action in ('view','click','search','cart','buy')),
  source_order_id uuid references public.store_orders(id) on delete cascade,
  event_at timestamptz not null default now()
);
create index if not exists product_recommendation_events_recent_idx
  on public.product_recommendation_events(event_at desc, action, product_id);
create index if not exists product_recommendation_events_user_idx
  on public.product_recommendation_events(user_id, event_at desc) where user_id is not null;
create unique index if not exists product_recommendation_events_order_product_idx
  on public.product_recommendation_events(source_order_id, product_id, action)
  where source_order_id is not null;
alter table public.product_recommendation_events enable row level security;
revoke all on public.product_recommendation_events from anon, authenticated;

-- A unique visitor is counted once per new seller product for exploration testing.
create table if not exists public.product_recommendation_exposures (
  product_id bigint not null,
  visitor_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  first_seen_at timestamptz not null default now(),
  clicked_at timestamptz,
  purchased_at timestamptz,
  primary key(product_id, visitor_id)
);
create index if not exists product_recommendation_exposures_recent_idx
  on public.product_recommendation_exposures(first_seen_at desc, product_id);
alter table public.product_recommendation_exposures enable row level security;
revoke all on public.product_recommendation_exposures from anon, authenticated;

create table if not exists public.product_recommendation_rankings (
  product_id bigint primary key,
  score numeric(10,4) not null default 0,
  sales_30d bigint not null default 0,
  clicks_30d bigint not null default 0,
  searches_24h bigint not null default 0,
  clicks_24h bigint not null default 0,
  rating_average numeric(4,2),
  rating_count bigint not null default 0,
  new_boost numeric(5,2) not null default 0,
  fast_delivery_boost numeric(5,2) not null default 0,
  exploration_impressions bigint not null default 0,
  exploration_clicks bigint not null default 0,
  exploration_ctr numeric(6,5) not null default 0,
  created_at timestamptz,
  refreshed_at timestamptz not null default now()
);
create index if not exists product_recommendation_rankings_score_idx
  on public.product_recommendation_rankings(score desc, product_id);
alter table public.product_recommendation_rankings enable row level security;
drop policy if exists "Recommendation rankings are public" on public.product_recommendation_rankings;
create policy "Recommendation rankings are public" on public.product_recommendation_rankings
  for select to anon, authenticated using (true);
grant select on public.product_recommendation_rankings to anon, authenticated;

-- Active campaigns are clearly marked as sponsored in the storefront.
create table if not exists public.sponsored_product_campaigns (
  id uuid primary key default gen_random_uuid(),
  seller_product_id bigint not null references public.seller_products(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  requested_days smallint not null check (requested_days between 1 and 30),
  amount numeric(12,2) check (amount is null or amount >= 0),
  status text not null default 'pending_payment'
    check (status in ('pending_payment','active','rejected','expired')),
  payment_reference text,
  paid_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists sponsored_product_campaigns_active_idx
  on public.sponsored_product_campaigns(status, starts_at, ends_at);
create index if not exists sponsored_product_campaigns_owner_idx
  on public.sponsored_product_campaigns(owner_id, created_at desc);
alter table public.sponsored_product_campaigns enable row level security;
revoke all on public.sponsored_product_campaigns from anon, authenticated;

-- Browser tracking accepts only non-purchase actions. Orders create authoritative buy events below.
create or replace function public.record_product_recommendation_event(
  p_product_id bigint,
  p_action text,
  p_visitor_id uuid
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_product_id is null or p_product_id < 1 or p_action not in ('view','click','search','cart') then
    raise exception 'Invalid recommendation event.';
  end if;
  if auth.uid() is null and p_visitor_id is null then raise exception 'Visitor ID is required.'; end if;
  -- A click must qualify the already-counted impression even if event deduplication
  -- suppresses a repeated click event.
  if p_action='click' and p_visitor_id is not null then
    update public.product_recommendation_exposures
      set clicked_at=coalesce(clicked_at,now())
      where product_id=p_product_id and visitor_id=coalesce(auth.uid(),p_visitor_id);
  end if;
  if exists (
    select 1 from public.product_recommendation_events e
    where e.product_id=p_product_id and e.action=p_action and e.event_at>now()-interval '2 minutes'
      and ((auth.uid() is not null and e.user_id=auth.uid()) or e.visitor_id=p_visitor_id)
  ) then return; end if;
  insert into public.product_recommendation_events(product_id,user_id,visitor_id,action)
  values(p_product_id,auth.uid(),p_visitor_id,p_action);
end;
$$;
revoke all on function public.record_product_recommendation_event(bigint,text,uuid) from public;
grant execute on function public.record_product_recommendation_event(bigint,text,uuid) to anon, authenticated;

create or replace function public.record_product_recommendation_impressions(
  p_product_ids bigint[], p_visitor_id uuid
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_visitor_id is null then raise exception 'Visitor ID is required.'; end if;
  insert into public.product_recommendation_exposures(product_id,visitor_id,user_id)
  select distinct ids.product_id,coalesce(auth.uid(),p_visitor_id),auth.uid()
  from unnest(coalesce(p_product_ids,'{}'::bigint[])) as ids(product_id)
  join public.seller_products p on ids.product_id=1000000000::bigint+p.id
  where p.created_at>=now()-interval '30 days'
  on conflict(product_id,visitor_id) do nothing;
end;
$$;
revoke all on function public.record_product_recommendation_impressions(bigint[],uuid) from public;
grant execute on function public.record_product_recommendation_impressions(bigint[],uuid) to anon, authenticated;

-- Private, account-scoped event history for the For You shelf.
create or replace function public.get_my_product_recommendation_events()
returns table(product_id bigint, action text, event_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select e.product_id,e.action,e.event_at
  from public.product_recommendation_events e
  where e.user_id=auth.uid() and e.event_at>=now()-interval '180 days'
  order by e.event_at desc limit 500;
$$;
revoke all on function public.get_my_product_recommendation_events() from public, anon;
grant execute on function public.get_my_product_recommendation_events() to authenticated;

-- Rebuild rankings from the last 30 days. Components are normalized to 0–1 before applying
-- the requested weights, so the score stays interpretable and bounded near 0–100.
create or replace function public.refresh_product_recommendation_rankings()
returns void language plpgsql security definer set search_path = public
as $$
begin
  update public.sponsored_product_campaigns set status='expired',updated_at=now()
    where status='active' and ends_at<=now();
  with event_stats as (
    select e.product_id,
      count(*) filter(where e.action='click' and e.event_at>=now()-interval '30 days')::bigint as clicks_30d,
      count(*) filter(where e.action='search' and e.event_at>=now()-interval '24 hours')::bigint as searches_24h,
      count(*) filter(where e.action='click' and e.event_at>=now()-interval '24 hours')::bigint as clicks_24h
    from public.product_recommendation_events e
    where e.event_at>=now()-interval '30 days'
    group by e.product_id
  ), sales as (
    select case when p.id is not null then 1000000000::bigint+p.id
      else case when (item.value->>'product_id') ~ '^[0-9]+$' then (item.value->>'product_id')::bigint end end as product_id,
      sum(case when item.value->>'quantity' ~ '^[0-9]+$' then (item.value->>'quantity')::bigint else 1 end)::bigint as sales_30d
    from public.store_orders o
    cross join lateral jsonb_array_elements(o.items) as item(value)
    left join public.seller_products p on p.shop_id=o.shop_id
      and (item.value->>'product_id') ~ '^[0-9]+$'
      and p.id=case when (item.value->>'product_id') ~ '^[0-9]+$' then (item.value->>'product_id')::bigint else null end
    where o.status<>'cancelled' and o.created_at>=now()-interval '30 days'
      and (item.value->>'product_id') ~ '^[0-9]+$'
    group by 1
  ), ratings as (
    select product_id::bigint,count(rating)::bigint as rating_count,avg(rating)::numeric(4,2) as rating_average
    from public.product_reviews where rating between 1 and 5 group by product_id
  ), exposure_stats as (
    select x.product_id,count(*)::bigint as impressions,
      count(*) filter(where x.clicked_at is not null)::bigint as clicks
    from public.product_recommendation_exposures x
    where x.first_seen_at>=now()-interval '30 days'
    group by x.product_id
  ), catalog as (
    select (1000000000::bigint+p.id) as product_id,p.created_at,p.delivery_days
    from public.seller_products p where p.stock>0
  ), all_ids as (
    select product_id from catalog
    union select product_id from event_stats
    union select product_id from sales
    union select product_id from ratings
  ), features as (
    select ids.product_id,c.created_at,c.delivery_days,
      coalesce(sa.sales_30d,0) as sales_30d,coalesce(es.clicks_30d,0) as clicks_30d,
      coalesce(es.searches_24h,0) as searches_24h,coalesce(es.clicks_24h,0) as clicks_24h,
      coalesce(r.rating_average,0) as rating_average,coalesce(r.rating_count,0) as rating_count,
      coalesce(x.impressions,0) as impressions,coalesce(x.clicks,0) as exposure_clicks,
      case when coalesce(x.impressions,0)>0 then coalesce(x.clicks,0)::numeric/x.impressions else 0 end as ctr
    from all_ids ids left join catalog c using(product_id)
      left join sales sa using(product_id) left join event_stats es using(product_id)
      left join ratings r using(product_id) left join exposure_stats x using(product_id)
  ), scored as (
    select f.*,
      case when f.created_at>=now()-interval '7 days'
            and (f.impressions<100 or (f.ctr>0.05 and f.sales_30d>0)) then 15::numeric
           when f.created_at>=now()-interval '30 days' and f.ctr>0.05 and f.sales_30d>0 then 15::numeric
           else 0::numeric end as new_boost,
      case when f.delivery_days between 1 and 3 then 10::numeric else 0::numeric end as fast_boost,
      30*least(1,ln(1+f.sales_30d::numeric)/ln(101::numeric))
        +25*least(1,f.rating_average/5)
        +20*least(1,ln(1+f.clicks_30d::numeric)/ln(1001::numeric))
        +case when f.created_at>=now()-interval '7 days'
                   and (f.impressions<100 or (f.ctr>0.05 and f.sales_30d>0)) then 15
              when f.created_at>=now()-interval '30 days' and f.ctr>0.05 and f.sales_30d>0 then 15 else 0 end
        +case when f.delivery_days between 1 and 3 then 10 else 0 end as score
    from features f
  )
  insert into public.product_recommendation_rankings(
    product_id,score,sales_30d,clicks_30d,searches_24h,clicks_24h,rating_average,rating_count,
    new_boost,fast_delivery_boost,exploration_impressions,exploration_clicks,exploration_ctr,created_at,refreshed_at
  )
  select product_id,round(score::numeric,4),sales_30d,clicks_30d,searches_24h,clicks_24h,
    nullif(rating_average,0),rating_count,new_boost,fast_boost,impressions,exposure_clicks,ctr,created_at,now()
  from scored
  on conflict(product_id) do update set score=excluded.score,sales_30d=excluded.sales_30d,
    clicks_30d=excluded.clicks_30d,searches_24h=excluded.searches_24h,clicks_24h=excluded.clicks_24h,
    rating_average=excluded.rating_average,rating_count=excluded.rating_count,new_boost=excluded.new_boost,
    fast_delivery_boost=excluded.fast_delivery_boost,exploration_impressions=excluded.exploration_impressions,
    exploration_clicks=excluded.exploration_clicks,exploration_ctr=excluded.exploration_ctr,
    created_at=excluded.created_at,refreshed_at=now();

  delete from public.product_recommendation_rankings r
  where r.refreshed_at<now()-interval '2 hours';
end;
$$;
revoke all on function public.refresh_product_recommendation_rankings() from public, anon, authenticated;

create or replace function public.get_product_recommendation_rankings()
returns table(product_id bigint,score numeric,sales_30d bigint,clicks_30d bigint,searches_24h bigint,
  clicks_24h bigint,rating_average numeric,rating_count bigint,new_boost numeric,
  fast_delivery_boost numeric,exploration_impressions bigint,exploration_clicks bigint,
  exploration_ctr numeric,created_at timestamptz,is_sponsored boolean)
language sql stable security definer set search_path = public
as $$
  select r.product_id,r.score,r.sales_30d,r.clicks_30d,r.searches_24h,r.clicks_24h,
    r.rating_average,r.rating_count,r.new_boost,r.fast_delivery_boost,r.exploration_impressions,
    r.exploration_clicks,r.exploration_ctr,r.created_at,
    exists(select 1 from public.sponsored_product_campaigns c
      where r.product_id=1000000000::bigint+c.seller_product_id and c.status='active'
        and c.paid_at is not null and c.starts_at<=now() and c.ends_at>now()) as is_sponsored
  from public.product_recommendation_rankings r
  order by is_sponsored desc,r.score desc,r.sales_30d desc,r.clicks_30d desc,r.product_id;
$$;
revoke all on function public.get_product_recommendation_rankings() from public;
grant execute on function public.get_product_recommendation_rankings() to anon, authenticated;

-- The order trigger is the trusted source of purchase events; cancelled orders stop contributing to sales.
create or replace function public.log_recommendation_order_items()
returns trigger language plpgsql security definer set search_path = public
as $$
declare item jsonb; raw_id bigint; mapped_id bigint;
begin
  if tg_op='UPDATE' then
    if new.status='cancelled' and old.status<>'cancelled' then
      delete from public.product_recommendation_events where source_order_id=new.id and action='buy';
    end if;
    return new;
  end if;
  for item in select value from jsonb_array_elements(new.items) loop
    if coalesce(item->>'product_id','') ~ '^[0-9]+$' then
      raw_id:=(item->>'product_id')::bigint;
    select case when exists(select 1 from public.seller_products p where p.id=raw_id and p.shop_id=new.shop_id)
        then 1000000000::bigint+raw_id else raw_id end into mapped_id;
      insert into public.product_recommendation_events(product_id,user_id,action,source_order_id)
      values(mapped_id,new.user_id,'buy',new.id) on conflict do nothing;
    end if;
  end loop;
  update public.product_recommendation_exposures x set purchased_at=coalesce(x.purchased_at,now())
    where new.user_id is not null and x.product_id in (select case when p.id is not null then 1000000000::bigint+p.id
      else case when (item.value->>'product_id') ~ '^[0-9]+$' then (item.value->>'product_id')::bigint end end
      from jsonb_array_elements(new.items) item(value)
      left join public.seller_products p on p.shop_id=new.shop_id and (item.value->>'product_id') ~ '^[0-9]+$'
        and p.id=case when (item.value->>'product_id') ~ '^[0-9]+$' then (item.value->>'product_id')::bigint else null end)
      and x.user_id=new.user_id
      and x.first_seen_at>=now()-interval '30 days';
  return new;
end;
$$;
drop trigger if exists store_orders_recommendation_events on public.store_orders;
create trigger store_orders_recommendation_events
  after insert or update of status on public.store_orders
  for each row execute function public.log_recommendation_order_items();

-- Sellers request a paid slot; a host sets the price and marks payment received before activation.
create or replace function public.request_sponsored_product(p_seller_product_id bigint,p_requested_days smallint default 7)
returns uuid language plpgsql security definer set search_path = public
as $$
declare campaign_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to request sponsored placement.'; end if;
  if p_requested_days not between 1 and 30 then raise exception 'Choose 1 to 30 days.'; end if;
  if not exists(select 1 from public.seller_products p where p.id=p_seller_product_id and p.owner_id=auth.uid()) then
    raise exception 'This product is not in your shop.';
  end if;
  update public.sponsored_product_campaigns set status='expired',updated_at=now()
    where seller_product_id=p_seller_product_id and status='active' and ends_at<=now();
  if exists(select 1 from public.sponsored_product_campaigns c where c.seller_product_id=p_seller_product_id and c.status in ('pending_payment','active')) then
    raise exception 'This product already has a pending or active sponsored request.';
  end if;
  insert into public.sponsored_product_campaigns(seller_product_id,owner_id,requested_days)
  values(p_seller_product_id,auth.uid(),p_requested_days) returning id into campaign_id;
  return campaign_id;
end;
$$;
revoke all on function public.request_sponsored_product(bigint,smallint) from public, anon;
grant execute on function public.request_sponsored_product(bigint,smallint) to authenticated;

create or replace function public.get_my_sponsored_product_requests()
returns table(id uuid,seller_product_id bigint,product_name text,requested_days smallint,amount numeric,status text,created_at timestamptz,starts_at timestamptz,ends_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select c.id,c.seller_product_id,p.name,c.requested_days,c.amount,c.status,c.created_at,c.starts_at,c.ends_at
  from public.sponsored_product_campaigns c join public.seller_products p on p.id=c.seller_product_id
  where c.owner_id=auth.uid() order by c.created_at desc limit 100;
$$;
revoke all on function public.get_my_sponsored_product_requests() from public, anon;
grant execute on function public.get_my_sponsored_product_requests() to authenticated;

create or replace function public.get_sponsored_product_requests_for_host()
returns table(id uuid,seller_product_id bigint,product_name text,shop_name text,owner_email text,requested_days smallint,amount numeric,status text,payment_reference text,created_at timestamptz,starts_at timestamptz,ends_at timestamptz,paid_at timestamptz)
language plpgsql stable security definer set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'Host access only.';
  end if;
  return query select c.id,c.seller_product_id,p.name,s.shop_name,u.email::text,c.requested_days,c.amount,c.status,c.payment_reference,c.created_at,c.starts_at,c.ends_at,c.paid_at
    from public.sponsored_product_campaigns c join public.seller_products p on p.id=c.seller_product_id
    join public.seller_shops s on s.id=p.shop_id join auth.users u on u.id=c.owner_id
    order by case when c.status='pending_payment' then 0 else 1 end,c.created_at desc limit 500;
end;
$$;
revoke all on function public.get_sponsored_product_requests_for_host() from public, anon;
grant execute on function public.get_sponsored_product_requests_for_host() to authenticated;

create or replace function public.review_sponsored_product_request(
  p_campaign_id uuid,p_amount numeric,p_paid boolean,p_payment_reference text default null,p_reject boolean default false
) returns void language plpgsql security definer set search_path = public
as $$
declare campaign record;
begin
  if lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'Host access only.';
  end if;
  if p_reject then
    update public.sponsored_product_campaigns set status='rejected',updated_at=now() where id=p_campaign_id;
    return;
  end if;
  select * into campaign from public.sponsored_product_campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Request not found.'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Enter a price greater than zero.'; end if;
  update public.sponsored_product_campaigns set amount=p_amount,
    status=case when p_paid then 'active' else 'pending_payment' end,
    payment_reference=nullif(left(trim(coalesce(p_payment_reference,'')),120),''),
    paid_at=case when p_paid then coalesce(paid_at,now()) else null end,
    starts_at=case when p_paid then coalesce(starts_at,now()) else null end,
    ends_at=case when p_paid then coalesce(ends_at,now()+make_interval(days=>requested_days)) else null end,
    updated_at=now()
  where id=p_campaign_id;
end;
$$;
revoke all on function public.review_sponsored_product_request(uuid,numeric,boolean,text,boolean) from public, anon;
grant execute on function public.review_sponsored_product_request(uuid,numeric,boolean,text,boolean) to authenticated;

-- Refresh once now. pg_cron schedules the same refresh hourly when enabled in Supabase.
select public.refresh_product_recommendation_rankings();
do $$
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname='alee-product-recommendation-hourly';
    perform cron.schedule('alee-product-recommendation-hourly','0 * * * *','select public.refresh_product_recommendation_rankings();');
  else
    raise notice 'Enable the pg_cron extension in Supabase, then rerun this schema to schedule hourly ranking refreshes.';
  end if;
exception when undefined_table or undefined_function then
  raise notice 'Enable pg_cron in Supabase and rerun this schema to schedule hourly ranking refreshes.';
end $$;
