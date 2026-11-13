-- Run once in the Supabase SQL Editor to enable host-managed banner pricing.
create table if not exists public.banner_ad_pricing (
  ad_type text primary key check (ad_type in ('country', 'popup', 'banner', 'verified')),
  base_price_usd numeric(10, 2) not null check (base_price_usd >= 0 and base_price_usd <= 100000),
  updated_at timestamptz not null default now()
);

alter table public.banner_ad_pricing enable row level security;

grant select on public.banner_ad_pricing to anon, authenticated;
grant insert, update on public.banner_ad_pricing to authenticated;

drop policy if exists "Anyone can view banner ad pricing" on public.banner_ad_pricing;
create policy "Anyone can view banner ad pricing"
  on public.banner_ad_pricing for select
  to anon, authenticated
  using (true);

drop policy if exists "Only aleeshopping hosts can manage banner ad pricing" on public.banner_ad_pricing;
create policy "Only aleeshopping hosts can manage banner ad pricing"
  on public.banner_ad_pricing for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'));

insert into public.banner_ad_pricing (ad_type, base_price_usd)
values ('country', 6), ('popup', 4), ('banner', 12), ('verified', 10)
on conflict (ad_type) do nothing;
