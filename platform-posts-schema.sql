-- Run once in Supabase SQL Editor. Authenticated buyers and sellers may post
-- apps, games, advertisements, and jobs. Posts appear publicly immediately.

create table if not exists public.platform_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  shop_id uuid references public.seller_shops(id) on delete set null,
  post_type text not null check (post_type in ('app','game','ad','job')),
  title text not null check (char_length(title) between 2 and 120),
  category text not null default 'Other' check (char_length(category) <= 100),
  description text not null default '' check (char_length(description) <= 2000),
  link_url text not null default '' check (char_length(link_url) <= 1000),
  media_url text not null default '' check (char_length(media_url) <= 1000),
  location text not null default '' check (char_length(location) <= 120),
  employment_type text not null default '' check (char_length(employment_type) <= 80),
  salary text not null default '' check (char_length(salary) <= 100),
  created_at timestamptz not null default now()
);
alter table public.platform_posts add column if not exists shop_id uuid references public.seller_shops(id) on delete set null;
update public.platform_posts p set shop_id = s.id
from public.seller_shops s
where p.post_type = 'job' and p.owner_id = s.owner_id and p.shop_id is null;
create index if not exists platform_posts_type_created_idx on public.platform_posts(post_type, created_at desc);
create index if not exists platform_posts_owner_created_idx on public.platform_posts(owner_id, created_at desc);
create index if not exists platform_posts_shop_idx on public.platform_posts(shop_id) where shop_id is not null;
alter table public.platform_posts enable row level security;
drop policy if exists "Anyone can read platform posts" on public.platform_posts;
create policy "Anyone can read platform posts" on public.platform_posts for select using (true);
drop policy if exists "Signed-in users can publish their own platform posts" on public.platform_posts;
create policy "Signed-in users can publish their own platform posts" on public.platform_posts for insert to authenticated
  with check (owner_id = (select auth.uid()) and (shop_id is null or exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))));
drop policy if exists "Users can edit their own platform posts" on public.platform_posts;
create policy "Users can edit their own platform posts" on public.platform_posts for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()) and (shop_id is null or exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))));
drop policy if exists "Users can delete their own platform posts" on public.platform_posts;
create policy "Users can delete their own platform posts" on public.platform_posts for delete to authenticated
  using (owner_id = (select auth.uid()));
grant select on public.platform_posts to anon, authenticated;
grant insert, update, delete on public.platform_posts to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('platform-posts', 'platform-posts', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];
drop policy if exists "Anyone can read platform post images" on storage.objects;
create policy "Anyone can read platform post images" on storage.objects for select
  using (bucket_id = 'platform-posts');
drop policy if exists "Signed-in users can upload platform post images" on storage.objects;
create policy "Signed-in users can upload platform post images" on storage.objects for insert to authenticated
  with check (bucket_id = 'platform-posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Users can delete their platform post images" on storage.objects;
create policy "Users can delete their platform post images" on storage.objects for delete to authenticated
  using (bucket_id = 'platform-posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
