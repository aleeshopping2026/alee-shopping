-- Run after seller-marketplace-schema.sql. Host-managed, time-limited verified badges.
create table if not exists public.shop_verified_badges (
  shop_id uuid primary key references public.seller_shops(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  notes text not null default '' check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.shop_verified_badges enable row level security;
drop policy if exists "Alee hosts can read verified badges" on public.shop_verified_badges;
create policy "Alee hosts can read verified badges" on public.shop_verified_badges for select to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));
drop policy if exists "Alee hosts can grant verified badges" on public.shop_verified_badges;
create policy "Alee hosts can grant verified badges" on public.shop_verified_badges for insert to authenticated
  with check (lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));
drop policy if exists "Alee hosts can update verified badges" on public.shop_verified_badges;
create policy "Alee hosts can update verified badges" on public.shop_verified_badges for update to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'))
  with check (lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));
drop policy if exists "Alee hosts can revoke verified badges" on public.shop_verified_badges;
create policy "Alee hosts can revoke verified badges" on public.shop_verified_badges for delete to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));
grant select, insert, update, delete on public.shop_verified_badges to authenticated;

-- Expose only the active badge flag and expiry on the existing public shop profile view.
create or replace view public.seller_shops_profile_public
with (security_barrier = true)
as select s.id, s.shop_name, s.phone, s.phone2, s.address, s.external_link, s.created_at,
          s.logo_url, s.shop_category, s.youtube_url, s.instagram_url, s.facebook_url, s.bio,
          s.tiktok_url, s.country_code, s.currency_code,
          (b.shop_id is not null) as is_verified, b.expires_at as verified_until
from public.seller_shops s
left join public.shop_verified_badges b on b.shop_id = s.id
  and (b.expires_at is null or b.expires_at > now());
grant select on public.seller_shops_profile_public to anon, authenticated;
