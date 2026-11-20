-- ALEE host-only shop access controls.
-- Run after seller-marketplace-schema.sql, seller-orders-schema.sql,
-- product-listing-options-schema.sql, product-recommendations-schema.sql,
-- verified-badges-schema.sql, seller-dashboard-profile-schema.sql,
-- platform-posts-schema.sql, and feed-posts-schema.sql.

alter table public.seller_shops
  add column if not exists is_locked boolean not null default false,
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by uuid references auth.users(id) on delete set null,
  add column if not exists lock_reason text;

create or replace function public.protect_seller_shop_access_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if (new.is_locked, new.locked_at, new.locked_by, new.lock_reason)
     is distinct from (old.is_locked, old.locked_at, old.locked_by, old.lock_reason)
     and lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'Only an ALEE administrator can change shop access.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_seller_shop_access_fields on public.seller_shops;
create trigger protect_seller_shop_access_fields
  before update on public.seller_shops
  for each row execute function public.protect_seller_shop_access_fields();

create or replace function public.prevent_locked_seller_shop_delete()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if old.is_locked
     and lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'This shop is locked. Contact ALEE support before deleting it.' using errcode = '42501';
  end if;
  return old;
end;
$$;

drop trigger if exists prevent_locked_seller_shop_delete on public.seller_shops;
create trigger prevent_locked_seller_shop_delete
  before delete on public.seller_shops
  for each row execute function public.prevent_locked_seller_shop_delete();

-- Shop owners cannot edit a locked shop or its product listings.
drop policy if exists "Owners can update their seller shop" on public.seller_shops;
create policy "Owners can update their seller shop" on public.seller_shops
  for update to authenticated
  using ((select auth.uid()) = owner_id and not is_locked)
  with check ((select auth.uid()) = owner_id and not is_locked);

drop policy if exists "Owners can create their seller products" on public.seller_products;
create policy "Owners can create their seller products" on public.seller_products
  for insert to authenticated with check (
    (select auth.uid()) = owner_id and exists (
      select 1 from public.seller_shops s
      where s.id = shop_id and s.owner_id = (select auth.uid()) and not s.is_locked
    )
  );

drop policy if exists "Owners can update their seller products" on public.seller_products;
create policy "Owners can update their seller products" on public.seller_products
  for update to authenticated
  using ((select auth.uid()) = owner_id and exists (
    select 1 from public.seller_shops s where s.id = shop_id and not s.is_locked
  ))
  with check ((select auth.uid()) = owner_id and exists (
    select 1 from public.seller_shops s where s.id = shop_id and not s.is_locked
  ));

drop policy if exists "Owners can delete their seller products" on public.seller_products;
create policy "Owners can delete their seller products" on public.seller_products
  for delete to authenticated using (
    (select auth.uid()) = owner_id and exists (
      select 1 from public.seller_shops s where s.id = shop_id and not s.is_locked
    )
  );

-- Used by order RLS so cached cart items cannot be ordered after a shop is locked.
create or replace function public.seller_shop_is_unlocked(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.seller_shops s where s.id = p_shop_id and not s.is_locked
  );
$$;
revoke all on function public.seller_shop_is_unlocked(uuid) from public;
grant execute on function public.seller_shop_is_unlocked(uuid) to anon, authenticated;

drop policy if exists "Buyers can submit new orders" on public.store_orders;
create policy "Buyers can submit new orders" on public.store_orders
  for insert to anon, authenticated with check (
    status = 'new'
    and user_id is not distinct from (select auth.uid())
    and (shop_id is null or public.seller_shop_is_unlocked(shop_id))
  );

-- Locked shop posts and jobs are also hidden and cannot be newly published.
drop policy if exists "Anyone can view Feed posts" on public.feed_posts;
create policy "Anyone can view Feed posts" on public.feed_posts
  for select to anon, authenticated using (public.seller_shop_is_unlocked(shop_id));
drop policy if exists "Shop owners can create Feed posts" on public.feed_posts;
create policy "Shop owners can create Feed posts" on public.feed_posts
  for insert to authenticated with check (
    owner_id = (select auth.uid()) and public.seller_shop_is_unlocked(shop_id)
    and exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
  );

drop policy if exists "Anyone can read platform posts" on public.platform_posts;
create policy "Anyone can read platform posts" on public.platform_posts
  for select using (shop_id is null or public.seller_shop_is_unlocked(shop_id));
drop policy if exists "Signed-in users can publish their own platform posts" on public.platform_posts;
create policy "Signed-in users can publish their own platform posts" on public.platform_posts
  for insert to authenticated with check (
    owner_id = (select auth.uid())
    and (post_type <> 'ad' or lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'))
    and (shop_id is null or (
      public.seller_shop_is_unlocked(shop_id)
      and exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
    ))
  );
drop policy if exists "Users can edit their own platform posts" on public.platform_posts;
create policy "Users can edit their own platform posts" on public.platform_posts
  for update to authenticated
  using (
    ((owner_id = (select auth.uid()) and post_type <> 'ad')
      or (post_type = 'ad' and lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com')))
    and (shop_id is null or public.seller_shop_is_unlocked(shop_id))
  )
  with check (
    ((owner_id = (select auth.uid()) and post_type <> 'ad')
      or (post_type = 'ad' and lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com')))
    and (shop_id is null or public.seller_shop_is_unlocked(shop_id))
    and (shop_id is null
      or (post_type = 'ad' and lower(coalesce((select auth.jwt()->>'email'),'')) in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com'))
      or exists (select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid())))
  );

-- Preserve the existing public view columns, while hiding locked shops and their items.
create or replace view public.seller_shops_profile_public
with (security_barrier = true)
as select s.id, s.shop_name, s.phone, s.phone2, s.address, s.external_link, s.created_at,
          s.logo_url, s.shop_category, s.youtube_url, s.instagram_url, s.facebook_url, s.bio,
          s.tiktok_url, s.country_code, s.currency_code,
          (b.shop_id is not null) as is_verified, b.expires_at as verified_until,
          s.banner_url
from public.seller_shops s
left join public.shop_verified_badges b on b.shop_id = s.id
  and (b.expires_at is null or b.expires_at > now())
where not s.is_locked;
grant select on public.seller_shops_profile_public to anon, authenticated;

create or replace view public.seller_products_profile_public
with (security_barrier = true)
as
select p.id, p.shop_id, p.name, p.price, p.category, p.category_label, p.description,
       p.features, p.sizes, p.image_urls, p.created_at, p.wholesale_price,
       p.offer_price, p.stock, p.condition, p.colors,
       coalesce(s.currency_code, 'LKR') as currency_code,
       p.free_shipping,
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
       p.delivery_days
from public.seller_products p
join public.seller_shops s on s.id = p.shop_id
where not s.is_locked;
grant select on public.seller_products_profile_public to anon, authenticated;

-- The manager RPC is the only API that returns shop-owner email addresses.
create or replace function public.admin_list_shop_access()
returns table(
  shop_id uuid,
  shop_name text,
  owner_email text,
  logo_url text,
  shop_category text,
  created_at timestamptz,
  is_locked boolean,
  locked_at timestamptz,
  lock_reason text
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'Only an ALEE administrator can view shop owner emails.' using errcode = '42501';
  end if;

  return query
    select s.id, s.shop_name, u.email::text, s.logo_url, s.shop_category,
           s.created_at, s.is_locked, s.locked_at, s.lock_reason
    from public.seller_shops s
    join auth.users u on u.id = s.owner_id
    order by s.created_at desc;
end;
$$;

create or replace function public.admin_set_shop_lock(p_shop_id uuid, p_locked boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if lower(coalesce(auth.jwt()->>'email','')) not in ('aleeshopping2026@gmail.com','aleeshopping@gmail.com') then
    raise exception 'Only an ALEE administrator can lock or unlock shops.' using errcode = '42501';
  end if;
  if p_shop_id is null or p_locked is null then
    raise exception 'A shop and lock state are required.' using errcode = '22023';
  end if;

  update public.seller_shops
  set is_locked = p_locked,
      locked_at = case when p_locked then now() else null end,
      locked_by = case when p_locked then auth.uid() else null end,
      lock_reason = case when p_locked then nullif(left(trim(coalesce(p_reason,'')),500),'') else null end,
      updated_at = now()
  where id = p_shop_id;

  if not found then raise exception 'Shop not found.' using errcode = 'P0002'; end if;
end;
$$;

revoke all on function public.admin_list_shop_access() from public, anon;
revoke all on function public.admin_set_shop_lock(uuid, boolean, text) from public, anon;
grant execute on function public.admin_list_shop_access() to authenticated;
grant execute on function public.admin_set_shop_lock(uuid, boolean, text) to authenticated;

notify pgrst, 'reload schema';
