-- Run in Supabase SQL Editor after seller-marketplace-schema.sql.
-- Photo-only shop Feed posts, likes, comments, saved posts, and image storage.

create table if not exists public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  shop_id uuid not null,
  product_id bigint references public.seller_products(id) on delete set null,
  image_url text not null,
  storage_path text not null,
  caption text not null default '' check (char_length(caption) <= 1000),
  post_tag text not null default 'standard'
    check (post_tag in ('standard', 'announcement', 'offer')),
  created_at timestamptz not null default now(),
  constraint feed_posts_owner_shop_fk foreign key (shop_id, owner_id)
    references public.seller_shops(id, owner_id) on delete cascade
);

create or replace function public.validate_feed_product_link()
returns trigger language plpgsql set search_path = public, pg_temp
as $$
begin
  if new.product_id is not null and not exists (
    select 1 from public.seller_products p
    where p.id = new.product_id and p.shop_id = new.shop_id and p.owner_id = new.owner_id
  ) then
    raise exception 'Feed products must belong to the post shop.';
  end if;
  return new;
end;
$$;
drop trigger if exists feed_posts_validate_product_link on public.feed_posts;
create trigger feed_posts_validate_product_link
  before insert or update of product_id, shop_id, owner_id on public.feed_posts
  for each row execute function public.validate_feed_product_link();
revoke all on function public.validate_feed_product_link() from public, anon, authenticated;

create index if not exists feed_posts_recent_idx
  on public.feed_posts(created_at desc);
create index if not exists feed_posts_shop_recent_idx
  on public.feed_posts(shop_id, created_at desc);
create index if not exists feed_posts_owner_recent_idx
  on public.feed_posts(owner_id, created_at desc);

alter table public.feed_posts enable row level security;
drop policy if exists "Anyone can view Feed posts" on public.feed_posts;
create policy "Anyone can view Feed posts" on public.feed_posts
  for select to anon, authenticated using (true);
drop policy if exists "Shop owners can create Feed posts" on public.feed_posts;
create policy "Shop owners can create Feed posts" on public.feed_posts
  for insert to authenticated with check (
    owner_id = (select auth.uid()) and exists (
      select 1 from public.seller_shops s
      where s.id = shop_id and s.owner_id = (select auth.uid())
    )
  );
drop policy if exists "Shop owners can delete their Feed posts" on public.feed_posts;
create policy "Shop owners can delete their Feed posts" on public.feed_posts
  for delete to authenticated using (owner_id = (select auth.uid()));
grant select on public.feed_posts to anon, authenticated;
grant insert, delete on public.feed_posts to authenticated;

create table if not exists public.feed_likes (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists feed_likes_post_idx on public.feed_likes(post_id);
alter table public.feed_likes enable row level security;
drop policy if exists "Users can view their own Feed likes" on public.feed_likes;
create policy "Users can view their own Feed likes" on public.feed_likes
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Users can like Feed posts as themselves" on public.feed_likes;
create policy "Users can like Feed posts as themselves" on public.feed_likes
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users can remove their own Feed likes" on public.feed_likes;
create policy "Users can remove their own Feed likes" on public.feed_likes
  for delete to authenticated using (user_id = (select auth.uid()));
grant select, insert, delete on public.feed_likes to authenticated;

create or replace function public.get_feed_like_counts(p_post_ids uuid[])
returns table (post_id uuid, like_count bigint)
language sql stable security definer set search_path = public, pg_temp
as $$
  select likes.post_id, count(*)::bigint
  from public.feed_likes likes
  where likes.post_id = any(p_post_ids)
  group by likes.post_id;
$$;
revoke all on function public.get_feed_like_counts(uuid[]) from public;
grant execute on function public.get_feed_like_counts(uuid[]) to anon, authenticated;

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists feed_comments_post_created_idx
  on public.feed_comments(post_id, created_at);
alter table public.feed_comments enable row level security;
drop policy if exists "Anyone can view Feed comments" on public.feed_comments;
create policy "Anyone can view Feed comments" on public.feed_comments
  for select to anon, authenticated using (true);
drop policy if exists "Users can comment as themselves" on public.feed_comments;
create policy "Users can comment as themselves" on public.feed_comments
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users can delete their own Feed comments" on public.feed_comments;
create policy "Users can delete their own Feed comments" on public.feed_comments
  for delete to authenticated using (user_id = (select auth.uid()));
grant select on public.feed_comments to anon, authenticated;
grant insert, delete on public.feed_comments to authenticated;

create table if not exists public.feed_saved (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists feed_saved_user_created_idx
  on public.feed_saved(user_id, created_at desc);
alter table public.feed_saved enable row level security;
drop policy if exists "Users can view their own Saved Posts" on public.feed_saved;
create policy "Users can view their own Saved Posts" on public.feed_saved
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Users can save Feed posts as themselves" on public.feed_saved;
create policy "Users can save Feed posts as themselves" on public.feed_saved
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users can remove their own Saved Posts" on public.feed_saved;
create policy "Users can remove their own Saved Posts" on public.feed_saved
  for delete to authenticated using (user_id = (select auth.uid()));
grant select, insert, delete on public.feed_saved to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feed-posts', 'feed-posts', true, 10485760,
        array['image/jpeg','image/png','image/webp','image/gif','image/avif'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','image/avif'];

drop policy if exists "Anyone can view Feed photos" on storage.objects;
create policy "Anyone can view Feed photos" on storage.objects
  for select to anon, authenticated using (bucket_id = 'feed-posts');
drop policy if exists "Shop owners can upload Feed photos" on storage.objects;
create policy "Shop owners can upload Feed photos" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'feed-posts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.seller_shops s
      where s.id::text = (storage.foldername(name))[2]
        and s.owner_id = (select auth.uid())
    )
  );
drop policy if exists "Shop owners can delete their Feed photos" on storage.objects;
create policy "Shop owners can delete their Feed photos" on storage.objects
  for delete to authenticated using (
    bucket_id = 'feed-posts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
