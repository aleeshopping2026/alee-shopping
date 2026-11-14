-- Shared shop display order for the public shops directory and homepage shop strip.
-- Run once in Supabase Dashboard > SQL Editor. Safe to re-run.

create table if not exists public.shop_directory_settings (
  setting_key text primary key check (setting_key = 'main'),
  shop_order text[] not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.shop_directory_settings enable row level security;

grant select on public.shop_directory_settings to anon, authenticated;
grant insert, update on public.shop_directory_settings to authenticated;

drop policy if exists "Anyone can read the shop directory order" on public.shop_directory_settings;
create policy "Anyone can read the shop directory order"
  on public.shop_directory_settings for select to anon, authenticated
  using (true);

drop policy if exists "ALEE hosts can create the shop directory order" on public.shop_directory_settings;
create policy "ALEE hosts can create the shop directory order"
  on public.shop_directory_settings for insert to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'));

drop policy if exists "ALEE hosts can update the shop directory order" on public.shop_directory_settings;
create policy "ALEE hosts can update the shop directory order"
  on public.shop_directory_settings for update to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'));

insert into public.shop_directory_settings (setting_key, shop_order)
values ('main', '{}')
on conflict (setting_key) do nothing;
