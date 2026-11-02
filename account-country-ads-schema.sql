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

-- Only the site host may create, edit, or delete advertisement rows.
drop policy if exists "Signed-in users can publish their own platform posts" on public.platform_posts;
create policy "Signed-in users can publish their own platform posts" on public.platform_posts for insert to authenticated
  with check (owner_id = (select auth.uid()) and (post_type <> 'ad' or lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'aleeshopping2026@gmail.com') and (shop_id is null or exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))));
drop policy if exists "Users can edit their own platform posts" on public.platform_posts;
create policy "Users can edit their own platform posts" on public.platform_posts for update to authenticated
  using (owner_id = (select auth.uid()) and (post_type <> 'ad' or lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'aleeshopping2026@gmail.com'))
  with check (owner_id = (select auth.uid()) and (post_type <> 'ad' or lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'aleeshopping2026@gmail.com') and (shop_id is null or exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))));
drop policy if exists "Users can delete their own platform posts" on public.platform_posts;
create policy "Users can delete their own platform posts" on public.platform_posts for delete to authenticated
  using (owner_id = (select auth.uid()) and (post_type <> 'ad' or lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'aleeshopping2026@gmail.com'));
