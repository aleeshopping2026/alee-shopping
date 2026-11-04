-- Seller analytics. Run after seller-marketplace-schema.sql.
create table if not exists public.seller_shop_view_counts (shop_id uuid primary key references public.seller_shops(id) on delete cascade, view_count bigint not null default 0 check(view_count>=0), updated_at timestamptz not null default now());
create table if not exists public.seller_product_view_counts (product_id bigint primary key references public.seller_products(id) on delete cascade, shop_id uuid not null references public.seller_shops(id) on delete cascade, view_count bigint not null default 0 check(view_count>=0), updated_at timestamptz not null default now());
create index if not exists seller_product_view_counts_shop_idx on public.seller_product_view_counts(shop_id);
alter table public.seller_shop_view_counts enable row level security;
alter table public.seller_product_view_counts enable row level security;
drop policy if exists "Shop owners can read their shop view counts" on public.seller_shop_view_counts;
create policy "Shop owners can read their shop view counts" on public.seller_shop_view_counts for select to authenticated using (exists(select 1 from public.seller_shops s where s.id=shop_id and s.owner_id=(select auth.uid())));
drop policy if exists "Shop owners can read their product view counts" on public.seller_product_view_counts;
create policy "Shop owners can read their product view counts" on public.seller_product_view_counts for select to authenticated using (exists(select 1 from public.seller_shops s where s.id=shop_id and s.owner_id=(select auth.uid())));
grant select on public.seller_shop_view_counts, public.seller_product_view_counts to authenticated;
create or replace function public.track_seller_product_view(p_product_id bigint) returns void language plpgsql security definer set search_path=public as $$
declare v_shop_id uuid;
begin
 select shop_id into v_shop_id from public.seller_products where id=p_product_id;
 if v_shop_id is null then return; end if;
 insert into public.seller_product_view_counts(product_id,shop_id,view_count,updated_at) values(p_product_id,v_shop_id,1,now())
 on conflict(product_id) do update set view_count=public.seller_product_view_counts.view_count+1,updated_at=now();
 insert into public.seller_shop_view_counts(shop_id,view_count,updated_at) values(v_shop_id,1,now())
 on conflict(shop_id) do update set view_count=public.seller_shop_view_counts.view_count+1,updated_at=now();
end $$;
create or replace function public.track_seller_shop_view(p_shop_id uuid) returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.seller_shops where id=p_shop_id) then return; end if;
 insert into public.seller_shop_view_counts(shop_id,view_count,updated_at) values(p_shop_id,1,now())
 on conflict(shop_id) do update set view_count=public.seller_shop_view_counts.view_count+1,updated_at=now();
end $$;
revoke all on function public.track_seller_product_view(bigint) from public;
revoke all on function public.track_seller_shop_view(uuid) from public;
grant execute on function public.track_seller_product_view(bigint) to anon, authenticated;
grant execute on function public.track_seller_shop_view(uuid) to anon, authenticated;
