-- Allow a signed-in shopper to load only their own order rows in Orders.
-- Run after seller-orders-schema.sql has created public.store_orders.

create index if not exists store_orders_buyer_recent_idx
  on public.store_orders (user_id, created_at desc)
  where user_id is not null;

drop policy if exists "Buyers can read their own orders" on public.store_orders;
create policy "Buyers can read their own orders" on public.store_orders
  for select to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.store_orders to authenticated;
