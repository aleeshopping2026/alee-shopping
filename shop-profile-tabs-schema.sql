-- Shows each follower's public profile photo in shop follower lists.
-- Run after seller-profile-social-schema.sql in Supabase SQL Editor.
-- Only the profile display name and HTTPS avatar URL are returned; no email,
-- phone number, account ID, or private ALEE profile fields are exposed.

drop function if exists public.get_shop_followers(uuid);

create function public.get_shop_followers(p_shop_id uuid)
returns table(follower_name text, follower_avatar_url text, followed_at timestamptz)
language sql stable security definer set search_path = public, auth
as $$
  select
    f.follower_name,
    case when avatar.avatar_url ~* '^https://' then avatar.avatar_url else null end,
    f.created_at
  from public.shop_follows f
  left join auth.users u on u.id = f.follower_id
  left join lateral (
    select coalesce(
      nullif(u.raw_user_meta_data ->> 'avatar_url', ''),
      nullif(u.raw_user_meta_data ->> 'picture', ''),
      nullif(u.raw_user_meta_data ->> 'photo_url', '')
    ) as avatar_url
  ) avatar on true
  where f.shop_id = p_shop_id
  order by f.created_at desc
  limit 200;
$$;

revoke all on function public.get_shop_followers(uuid) from public;
grant execute on function public.get_shop_followers(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
