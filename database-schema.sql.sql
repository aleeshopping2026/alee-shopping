-- Run this once in Supabase SQL Editor.
-- Customer email addresses are held by Supabase Auth, not copied into public comments.
create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id integer not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.product_reviews enable row level security;
drop policy if exists "Anyone can read product comments" on public.product_reviews;
create policy "Anyone can read product comments"
  on public.product_reviews for select using (true);
drop policy if exists "Signed-in customers can post comments" on public.product_reviews;
create policy "Signed-in customers can post comments"
  on public.product_reviews for insert to authenticated
  with check (auth.uid() = user_id);

grant select on public.product_reviews to anon, authenticated;
grant insert on public.product_reviews to authenticated;
create index if not exists product_reviews_product_created_idx
  on public.product_reviews(product_id, created_at desc);
