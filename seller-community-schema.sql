-- Run once in Supabase SQL Editor after seller-marketplace-schema.sql.
-- Adds seller video reels with public viewing, likes, comments, saves, and owner uploads.

create table if not exists public.seller_reels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  shop_id uuid not null references public.seller_shops(id) on delete cascade,
  video_url text not null,
  storage_path text not null,
  caption text not null default '' check (char_length(caption) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists seller_reels_recent_idx on public.seller_reels(created_at desc);
create index if not exists seller_reels_shop_recent_idx on public.seller_reels(shop_id, created_at desc);
alter table public.seller_reels enable row level security;
drop policy if exists "Anyone can view seller reels" on public.seller_reels;
create policy "Anyone can view seller reels" on public.seller_reels for select using (true);
drop policy if exists "Shop owners can create their reels" on public.seller_reels;
create policy "Shop owners can create their reels" on public.seller_reels for insert to authenticated
  with check (owner_id = (select auth.uid()) and exists (
    select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid())
  ));
drop policy if exists "Shop owners can delete their reels" on public.seller_reels;
create policy "Shop owners can delete their reels" on public.seller_reels for delete to authenticated
  using (owner_id = (select auth.uid()));
grant select on public.seller_reels to anon, authenticated;
grant insert, delete on public.seller_reels to authenticated;

create table if not exists public.seller_reel_likes (
  reel_id uuid not null references public.seller_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);
alter table public.seller_reel_likes enable row level security;
drop policy if exists "Anyone can view reel likes" on public.seller_reel_likes;
drop policy if exists "Users can view their own reel likes" on public.seller_reel_likes;
create policy "Users can view their own reel likes" on public.seller_reel_likes for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "Users can like reels as themselves" on public.seller_reel_likes;
create policy "Users can like reels as themselves" on public.seller_reel_likes for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Users can remove their reel likes" on public.seller_reel_likes;
create policy "Users can remove their reel likes" on public.seller_reel_likes for delete to authenticated
  using (user_id = (select auth.uid()));
grant select on public.seller_reel_likes to authenticated;
grant insert, delete on public.seller_reel_likes to authenticated;

create or replace function public.get_seller_reel_like_counts(p_reel_ids uuid[])
returns table (reel_id uuid, like_count bigint)
language sql stable security definer set search_path = public
as $$
  select l.reel_id, count(*)::bigint
  from public.seller_reel_likes l
  where l.reel_id = any(p_reel_ids)
  group by l.reel_id;
$$;
grant execute on function public.get_seller_reel_like_counts(uuid[]) to anon, authenticated;

create table if not exists public.seller_reel_comments (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.seller_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default 'Shopper' check (char_length(display_name) <= 80),
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists seller_reel_comments_recent_idx on public.seller_reel_comments(reel_id, created_at);
alter table public.seller_reel_comments enable row level security;
drop policy if exists "Anyone can view reel comments" on public.seller_reel_comments;
create policy "Anyone can view reel comments" on public.seller_reel_comments for select using (true);
drop policy if exists "Signed-in users can comment as themselves" on public.seller_reel_comments;
create policy "Signed-in users can comment as themselves" on public.seller_reel_comments for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Users can delete their own reel comments" on public.seller_reel_comments;
create policy "Users can delete their own reel comments" on public.seller_reel_comments for delete to authenticated
  using (user_id = (select auth.uid()));
grant select on public.seller_reel_comments to anon, authenticated;
grant insert, delete on public.seller_reel_comments to authenticated;

create table if not exists public.seller_reel_saves (
  reel_id uuid not null references public.seller_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);
alter table public.seller_reel_saves enable row level security;
drop policy if exists "Users can view their reel saves" on public.seller_reel_saves;
create policy "Users can view their reel saves" on public.seller_reel_saves for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "Users can save reels as themselves" on public.seller_reel_saves;
create policy "Users can save reels as themselves" on public.seller_reel_saves for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Users can remove their reel saves" on public.seller_reel_saves;
create policy "Users can remove their reel saves" on public.seller_reel_saves for delete to authenticated
  using (user_id = (select auth.uid()));
grant select, insert, delete on public.seller_reel_saves to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('seller-reels', 'seller-reels', true, 52428800, array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = 52428800,
  allowed_mime_types = array['video/mp4','video/webm','video/quicktime'];
drop policy if exists "Anyone can view seller reel videos" on storage.objects;
create policy "Anyone can view seller reel videos" on storage.objects for select
  using (bucket_id = 'seller-reels');
drop policy if exists "Shop owners can upload reel videos" on storage.objects;
create policy "Shop owners can upload reel videos" on storage.objects for insert to authenticated
  with check (bucket_id = 'seller-reels' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Shop owners can delete reel videos" on storage.objects;
create policy "Shop owners can delete reel videos" on storage.objects for delete to authenticated
  using (bucket_id = 'seller-reels' and (storage.foldername(name))[1] = (select auth.uid())::text);
