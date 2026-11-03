-- Run after account-profile-schema.sql and seller-marketplace-schema.sql.
-- Existing shops and buyers default to Sri Lanka; users can change this in their profiles.
alter table public.seller_shops
  add column if not exists country_code text not null default 'LK'
  check (country_code ~ '^[A-Z]{2}$');
alter table public.seller_shops
  add column if not exists currency_code text not null default 'LKR'
  check (currency_code ~ '^[A-Z]{3}$');

alter table if exists public.alee_profiles
  add column if not exists country_code text not null default 'LK'
  check (country_code ~ '^[A-Z]{2}$');

create or replace view public.seller_shops_profile_public
with (security_barrier = true)
as select id, shop_name, phone, phone2, address, external_link, created_at,
          logo_url, shop_category, youtube_url, instagram_url, facebook_url, bio, tiktok_url, country_code, currency_code
from public.seller_shops;

grant select on public.seller_shops_profile_public to anon, authenticated;
