-- ALEE SHOPPING private account profiles and owner controlled shop removal.
-- Run in Supabase SQL Editor after seller-marketplace-schema.sql.

create table if not exists public.alee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 80),
  address text not null check (char_length(address) between 3 and 500),
  mobile text not null check (char_length(mobile) between 5 and 32),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.alee_profiles enable row level security;
revoke all on public.alee_profiles from public, anon, authenticated;
grant select, insert, update on public.alee_profiles to authenticated;

drop policy if exists "Users can read their own private ALEE profile" on public.alee_profiles;
create policy "Users can read their own private ALEE profile" on public.alee_profiles
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their own private ALEE profile" on public.alee_profiles;
create policy "Users can create their own private ALEE profile" on public.alee_profiles
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their own private ALEE profile" on public.alee_profiles;
create policy "Users can update their own private ALEE profile" on public.alee_profiles
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.delete_my_shop(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_owner_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to delete your shop.'; end if;
  select owner_id into v_owner_id from public.seller_shops
  where id = p_shop_id and owner_id = auth.uid() for update;
  if v_owner_id is null then raise exception 'Shop not found or you do not own it.'; end if;

  -- A confirmed shop deletion removes its associated order rows as well.
  if to_regclass('public.store_orders') is not null then
    execute 'delete from public.store_orders where shop_id = $1' using p_shop_id;
  end if;
  -- Existing foreign keys cascade shop products, reels, chats, and follows.
  delete from public.seller_shops where id = p_shop_id and owner_id = auth.uid();
end;
$$;

revoke all on function public.delete_my_shop(uuid) from public, anon;
grant execute on function public.delete_my_shop(uuid) to authenticated;
