-- Run after platform-posts-schema.sql so country-specific company ads can be shown in Account.
alter table public.platform_posts
  add column if not exists country_code text not null default 'LK'
  check (country_code ~ '^[A-Z]{2}$');

create index if not exists platform_posts_country_ads_idx
  on public.platform_posts(country_code, created_at desc)
  where post_type = 'ad';
