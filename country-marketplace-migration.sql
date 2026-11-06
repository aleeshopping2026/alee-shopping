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

-- seller-marketplace-schema.sql already exposes these fields in the public
-- profile view. Leave an existing (possibly verified-badge-extended) view intact.
grant select on public.seller_shops_profile_public to anon, authenticated;
