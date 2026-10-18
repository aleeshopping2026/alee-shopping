-- Safe additive upgrade for ALEE SHOPPING business profiles.
-- Run in Supabase SQL Editor after seller-marketplace-schema.sql is already installed.
-- This creates new profile views instead of replacing existing public views.

alter table public.seller_shops add column if not exists bio text not null default '' check (char_length(bio) <= 600);
alter table public.seller_shops add column if not exists tiktok_url text;

create or replace view public.seller_shops_profile_public
with (security_barrier = true)
as select id, shop_name, phone, phone2, address, external_link, created_at,
          logo_url, shop_category, youtube_url, instagram_url, facebook_url, bio, tiktok_url
from public.seller_shops;

create or replace view public.seller_products_profile_public
with (security_barrier = true)
as select id, shop_id, name, price, category, category_label, description,
          features, sizes, image_urls, created_at
from public.seller_products;

grant select on public.seller_shops_profile_public to anon, authenticated;
grant select on public.seller_products_profile_public to anon, authenticated;

create table if not exists public.shop_follows (
  shop_id uuid not null references public.seller_shops(id) on delete cascade,
  follower_id uuid not null references auth.users(id) on delete cascade,
  follower_name text not null default 'Shopper' check (char_length(follower_name) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (shop_id, follower_id)
);
alter table public.shop_follows enable row level security;
drop policy if exists "Users can read their own follows" on public.shop_follows;
create policy "Users can read their own follows" on public.shop_follows
  for select to authenticated using ((select auth.uid()) = follower_id);
drop policy if exists "Users can follow shops as themselves" on public.shop_follows;
create policy "Users can follow shops as themselves" on public.shop_follows
  for insert to authenticated with check ((select auth.uid()) = follower_id);
drop policy if exists "Users can update their own follow label" on public.shop_follows;
create policy "Users can update their own follow label" on public.shop_follows
  for update to authenticated using ((select auth.uid()) = follower_id)
  with check ((select auth.uid()) = follower_id);
drop policy if exists "Users can unfollow shops as themselves" on public.shop_follows;
create policy "Users can unfollow shops as themselves" on public.shop_follows
  for delete to authenticated using ((select auth.uid()) = follower_id);
grant select, insert, update, delete on public.shop_follows to authenticated;

create or replace function public.get_shop_social_data(p_shop_id uuid)
returns table(follower_count bigint, following_count bigint, is_following boolean)
language sql stable security definer set search_path = public
as $$
  select
    (select count(*) from public.shop_follows f where f.shop_id = s.id),
    (select count(*) from public.shop_follows f where f.follower_id = s.owner_id),
    exists(select 1 from public.shop_follows f where f.shop_id = s.id and f.follower_id = auth.uid())
  from public.seller_shops s where s.id = p_shop_id;
$$;

create or replace function public.get_shop_followers(p_shop_id uuid)
returns table(follower_name text, followed_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select f.follower_name, f.created_at from public.shop_follows f
  where f.shop_id = p_shop_id order by f.created_at desc limit 200;
$$;

create or replace function public.get_shop_following(p_shop_id uuid)
returns table(id uuid, shop_name text, logo_url text)
language sql stable security definer set search_path = public
as $$
  select target.id, target.shop_name, target.logo_url
  from public.seller_shops source
  join public.shop_follows f on f.follower_id = source.owner_id
  join public.seller_shops target on target.id = f.shop_id
  where source.id = p_shop_id order by f.created_at desc limit 200;
$$;

create or replace function public.follow_shop(p_shop_id uuid, p_follower_name text)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in to follow a shop.'; end if;
  insert into public.shop_follows(shop_id, follower_id, follower_name)
  select s.id, auth.uid(), left(coalesce(nullif(trim(p_follower_name), ''), 'Shopper'), 80)
  from public.seller_shops s where s.id = p_shop_id
  on conflict (shop_id, follower_id) do update set follower_name = excluded.follower_name;
  if not found then raise exception 'Shop not found.'; end if;
end;
$$;

create or replace function public.unfollow_shop(p_shop_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in to unfollow a shop.'; end if;
  delete from public.shop_follows where shop_id = p_shop_id and follower_id = auth.uid();
end;
$$;

revoke all on function public.get_shop_social_data(uuid) from public;
revoke all on function public.get_shop_followers(uuid) from public;
revoke all on function public.get_shop_following(uuid) from public;
revoke all on function public.follow_shop(uuid, text) from public;
revoke all on function public.unfollow_shop(uuid) from public;
grant execute on function public.get_shop_social_data(uuid) to anon, authenticated;
grant execute on function public.get_shop_followers(uuid) to anon, authenticated;
grant execute on function public.get_shop_following(uuid) to anon, authenticated;
grant execute on function public.follow_shop(uuid, text) to authenticated;
grant execute on function public.unfollow_shop(uuid) to authenticated;

notify pgrst, 'reload schema';
