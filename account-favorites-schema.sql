-- Run in Supabase SQL Editor to sync Favorites with signed-in accounts.
create table if not exists public.user_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('product','job','shop')),
  item_id text not null check (char_length(item_id) between 1 and 160),
  item_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id,item_type,item_id)
);
create index if not exists user_favorites_recent_idx on public.user_favorites(user_id,created_at desc);
alter table public.user_favorites enable row level security;
drop policy if exists "Users can read their own favorites" on public.user_favorites;
create policy "Users can read their own favorites" on public.user_favorites for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "Users can save their own favorites" on public.user_favorites;
create policy "Users can save their own favorites" on public.user_favorites for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "Users can update their own favorites" on public.user_favorites;
create policy "Users can update their own favorites" on public.user_favorites for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists "Users can remove their own favorites" on public.user_favorites;
create policy "Users can remove their own favorites" on public.user_favorites for delete to authenticated using ((select auth.uid())=user_id);
grant select,insert,update,delete on public.user_favorites to authenticated;
