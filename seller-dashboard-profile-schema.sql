-- Shop profile header/banner and private signed-in profile-view history.
-- Run after seller-marketplace-schema.sql, verified-badges-schema.sql,
-- seller-profile-social-schema.sql, and seller-analytics-schema.sql.

alter table public.seller_shops add column if not exists banner_url text;
alter table public.seller_view_events
  add column if not exists viewer_user_id uuid references auth.users(id) on delete set null;
create index if not exists seller_view_events_profile_viewers_idx
  on public.seller_view_events(shop_id, created_at desc) where product_id is null and viewer_user_id is not null;

-- Keep the existing public-view columns in their current order and append the banner URL.
create or replace view public.seller_shops_profile_public
with (security_barrier = true)
as select s.id, s.shop_name, s.phone, s.phone2, s.address, s.external_link, s.created_at,
          s.logo_url, s.shop_category, s.youtube_url, s.instagram_url, s.facebook_url, s.bio,
          s.tiktok_url, s.country_code, s.currency_code,
          (b.shop_id is not null) as is_verified, b.expires_at as verified_until,
          s.banner_url
from public.seller_shops s
left join public.shop_verified_badges b on b.shop_id = s.id
  and (b.expires_at is null or b.expires_at > now());
grant select on public.seller_shops_profile_public to anon, authenticated;

alter table public.shop_follows add column if not exists follower_avatar_url text;
update public.shop_follows f
set follower_avatar_url = coalesce(
  nullif(u.raw_user_meta_data->>'avatar_url',''),
  nullif(u.raw_user_meta_data->>'picture','')
)
from auth.users u
where u.id = f.follower_id and f.follower_avatar_url is null
  and coalesce(nullif(u.raw_user_meta_data->>'avatar_url',''),nullif(u.raw_user_meta_data->>'picture','')) is not null;
drop function if exists public.get_shop_followers(uuid);
create function public.get_shop_followers(p_shop_id uuid)
returns table(follower_name text, follower_avatar_url text, followed_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select f.follower_name, f.follower_avatar_url, f.created_at
  from public.shop_follows f where f.shop_id = p_shop_id
  order by f.created_at desc limit 200;
$$;
revoke all on function public.get_shop_followers(uuid) from public;
create or replace function public.follow_shop(p_shop_id uuid, p_follower_name text)
returns void language plpgsql security definer set search_path = public, auth
as $$
declare v_avatar text;
begin
  if auth.uid() is null then raise exception 'Sign in to follow a shop.'; end if;
  v_avatar := coalesce(
    nullif(auth.jwt()->'user_metadata'->>'avatar_url',''),
    nullif(auth.jwt()->'user_metadata'->>'picture','')
  );
  insert into public.shop_follows(shop_id, follower_id, follower_name, follower_avatar_url)
  select s.id, auth.uid(), left(coalesce(nullif(trim(p_follower_name), ''), 'Shopper'), 80), v_avatar
  from public.seller_shops s where s.id = p_shop_id
  on conflict (shop_id, follower_id) do update
    set follower_name = excluded.follower_name, follower_avatar_url = excluded.follower_avatar_url;
  if not found then raise exception 'Shop not found.'; end if;
end;
$$;
revoke all on function public.follow_shop(uuid, text) from public;
grant execute on function public.get_shop_followers(uuid) to anon, authenticated;
grant execute on function public.follow_shop(uuid, text) to authenticated;

create or replace function public.track_seller_shop_view(p_shop_id uuid)
returns void language plpgsql security definer set search_path = public, auth
as $$
begin
  if not exists(select 1 from public.seller_shops where id = p_shop_id) then return; end if;
  insert into public.seller_shop_view_counts(shop_id,view_count,updated_at) values(p_shop_id,1,now())
  on conflict(shop_id) do update set view_count=public.seller_shop_view_counts.view_count+1,updated_at=now();
  insert into public.seller_view_events(shop_id,product_id,viewer_user_id)
  values(p_shop_id,null,auth.uid());
end;
$$;
revoke all on function public.track_seller_shop_view(uuid) from public;
grant execute on function public.track_seller_shop_view(uuid) to anon, authenticated;

create or replace function public.get_seller_profile_view_count(p_shop_id uuid)
returns bigint language plpgsql stable security definer set search_path = public
as $$
declare v_count bigint;
begin
  if auth.uid() is null or not exists(
    select 1 from public.seller_shops s where s.id=p_shop_id and s.owner_id=auth.uid()
  ) then raise exception 'Not allowed to view shop profile analytics.' using errcode='42501'; end if;
  select count(*) into v_count from public.seller_view_events e
  where e.shop_id=p_shop_id and e.product_id is null and e.created_at>=now()-interval '30 days';
  return coalesce(v_count,0);
end;
$$;

create or replace function public.get_my_seller_profile_viewers(p_shop_id uuid)
returns table(display_name text, avatar_url text, viewed_at timestamptz)
language plpgsql stable security definer set search_path = public, auth
as $$
begin
  if auth.uid() is null or not exists(
    select 1 from public.seller_shops s where s.id=p_shop_id and s.owner_id=auth.uid()
  ) then raise exception 'Not allowed to view profile viewers.' using errcode='42501'; end if;
  return query
    select coalesce(nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'name',''),nullif(u.raw_user_meta_data->>'display_name',''),'Shopper'),
           coalesce(nullif(u.raw_user_meta_data->>'avatar_url',''),nullif(u.raw_user_meta_data->>'picture','')),
           max(e.created_at)
    from public.seller_view_events e join auth.users u on u.id=e.viewer_user_id
    where e.shop_id=p_shop_id and e.product_id is null and e.viewer_user_id<>auth.uid()
      and e.created_at>=now()-interval '30 days'
    group by u.id,u.raw_user_meta_data
    order by max(e.created_at) desc limit 100;
end;
$$;

revoke all on function public.get_seller_profile_view_count(uuid) from public;
revoke all on function public.get_my_seller_profile_viewers(uuid) from public;
grant execute on function public.get_seller_profile_view_count(uuid) to authenticated;
grant execute on function public.get_my_seller_profile_viewers(uuid) to authenticated;

notify pgrst, 'reload schema';
