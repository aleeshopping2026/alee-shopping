-- ALEE host-only access for managing every seller shop, product, and product photo.
-- Run after seller-marketplace-schema.sql and seller-shop-access-admin-schema.sql.
-- Re-run safely after updates to refresh the admin photo cleanup policy.

drop policy if exists "ALEE admins can read all seller shops" on public.seller_shops;
create policy "ALEE admins can read all seller shops" on public.seller_shops
  for select to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));

drop policy if exists "ALEE admins can update all seller shops" on public.seller_shops;
create policy "ALEE admins can update all seller shops" on public.seller_shops
  for update to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'))
  with check (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));

drop policy if exists "ALEE admins can read all seller products" on public.seller_products;
create policy "ALEE admins can read all seller products" on public.seller_products
  for select to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));

drop policy if exists "ALEE admins can update all seller products" on public.seller_products;
create policy "ALEE admins can update all seller products" on public.seller_products
  for update to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'))
  with check (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));

drop policy if exists "ALEE admins can delete all seller products" on public.seller_products;
create policy "ALEE admins can delete all seller products" on public.seller_products
  for delete to authenticated
  using (lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'));

-- Let approved ALEE hosts remove replaced or deleted product photos from the public seller bucket.
drop policy if exists "ALEE admins can delete seller photos" on storage.objects;
create policy "ALEE admins can delete seller photos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'seller-uploads'
    and lower(coalesce((select auth.jwt()->>'email'), '')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com')
  );

notify pgrst, 'reload schema';
