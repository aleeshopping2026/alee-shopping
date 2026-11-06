-- Product listing options and public sold totals for the product detail view.
-- Run after seller-marketplace-schema.sql and seller-orders-schema.sql.
alter table public.seller_products
  add column if not exists free_shipping boolean not null default false;

create or replace view public.seller_products_profile_public
with (security_barrier = true)
as
select p.id, p.shop_id, p.name, p.price, p.category, p.category_label, p.description,
       p.features, p.sizes, p.image_urls, p.created_at, p.wholesale_price,
       p.offer_price, p.stock, p.condition, p.colors, p.free_shipping,
       coalesce((
         select sum(case
           when item.value->>'quantity' ~ '^[0-9]+$' then (item.value->>'quantity')::bigint
           else 1::bigint
         end)
         from public.store_orders o
         cross join lateral jsonb_array_elements(o.items) as item(value)
         where o.shop_id = p.shop_id
           and o.status <> 'cancelled'
           and item.value->>'product_id' = p.id::text
       ), 0)::bigint as sold_count,
       coalesce(s.currency_code, 'LKR') as currency_code
from public.seller_products p
join public.seller_shops s on s.id = p.shop_id;

grant select on public.seller_products_profile_public to anon, authenticated;
