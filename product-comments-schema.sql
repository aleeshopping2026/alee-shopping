-- Product comment photos and owner/host moderation (upgrade-safe).
-- Run this file once in Supabase SQL Editor after database-schema.sql.

alter table public.product_reviews
  add column if not exists images text[] not null default '{}',
  add column if not exists updated_at timestamptz not null default now();

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'product_reviews_max_two_images') then
    alter table public.product_reviews add constraint product_reviews_max_two_images
      check (cardinality(images) <= 2);
  end if;
end $$;

alter table public.product_reviews enable row level security;
drop policy if exists "Comment authors and ALEE hosts can edit comments" on public.product_reviews;
create policy "Comment authors and ALEE hosts can edit comments"
  on public.product_reviews for update to authenticated
  using (
    auth.uid() = user_id
    or lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  )
  with check (
    auth.uid() = user_id
    or lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  );
drop policy if exists "Comment authors and ALEE hosts can delete comments" on public.product_reviews;
create policy "Comment authors and ALEE hosts can delete comments"
  on public.product_reviews for delete to authenticated
  using (
    auth.uid() = user_id
    or lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  );
grant update, delete on public.product_reviews to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-comment-images', 'product-comment-images', true, 8388608,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 8388608,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view product comment photos" on storage.objects;
create policy "Public can view product comment photos"
  on storage.objects for select using (bucket_id = 'product-comment-images');
drop policy if exists "Users can upload their product comment photos" on storage.objects;
create policy "Users can upload their product comment photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'product-comment-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Authors and ALEE hosts can remove product comment photos" on storage.objects;
create policy "Authors and ALEE hosts can remove product comment photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-comment-images'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
    )
  );
