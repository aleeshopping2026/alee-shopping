-- Run after platform-posts-schema.sql so country-specific company ads can be shown in Account.
alter table public.platform_posts
  add column if not exists country_code text not null default 'LK'
  check (country_code ~ '^[A-Z]{2}$');

create index if not exists platform_posts_country_ads_idx
  on public.platform_posts(country_code, created_at desc)
  where post_type = 'ad';

-- Country ads can use a linked image or short video (maximum 50 MB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('platform-posts', 'platform-posts', true, 52428800,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = 52428800,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'];
