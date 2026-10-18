-- ALEE SHOPPING order inbox. Run once in Supabase SQL Editor.
-- Public buyers can submit orders; only the ALEE owner and the relevant shop owner can read them.
create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.seller_shops(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  customer_name text not null check (char_length(customer_name) between 1 and 120),
  customer_address text not null check (char_length(customer_address) between 3 and 600),
  customer_phone text not null check (char_length(customer_phone) between 5 and 40),
  customer_phone2 text,
  customer_note text,
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 50),
  total numeric(12,2) not null check (total > 0),
  payment_method text not null default 'Cash on Delivery',
  status text not null default 'new' check (status in ('new','confirmed','processing','shipped','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists store_orders_shop_recent_idx on public.store_orders (shop_id, created_at desc);
create index if not exists store_orders_recent_idx on public.store_orders (created_at desc);
alter table public.store_orders enable row level security;

drop policy if exists "Buyers can submit new orders" on public.store_orders;
create policy "Buyers can submit new orders" on public.store_orders
  for insert to anon, authenticated with check (
    status = 'new'
    and user_id is not distinct from (select auth.uid())
    -- The foreign key validates shop_id. Avoid querying seller_shops here:
    -- anonymous checkout cannot read that private table under its RLS policies.
  );

drop policy if exists "Shop owners and ALEE owner can read orders" on public.store_orders;
create policy "Shop owners and ALEE owner can read orders" on public.store_orders
  for select to authenticated using (
    lower(coalesce(auth.jwt() ->> 'email','')) = 'aleeshopping2026@gmail.com'
    or (shop_id is not null and exists (
      select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid())
    ))
  );

drop policy if exists "Shop owners and ALEE owner can update order status" on public.store_orders;
create policy "Shop owners and ALEE owner can update order status" on public.store_orders
  for update to authenticated using (
    lower(coalesce(auth.jwt() ->> 'email','')) = 'aleeshopping2026@gmail.com'
    or (shop_id is not null and exists (
      select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid())
    ))
  ) with check (
    lower(coalesce(auth.jwt() ->> 'email','')) = 'aleeshopping2026@gmail.com'
    or (shop_id is not null and exists (
      select 1 from public.seller_shops s where s.id = shop_id and s.owner_id = (select auth.uid())
    ))
  );

grant insert on public.store_orders to anon, authenticated;
grant select on public.store_orders to authenticated;
grant update (status) on public.store_orders to authenticated;

-- When a signed-in buyer orders from a seller-managed shop, post the order
-- details to both the shop owner's chat and the ALEE owner's chat. Guest orders
-- still appear in both relevant Orders inboxes, but cannot create a buyer chat.
create or replace function public.post_order_to_seller_chat()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_seller_id uuid;
  v_alee_owner_id uuid;
  v_conversation_id uuid;
  v_buyer_label text;
  v_shop_name text;
  v_message text;
begin
  if new.user_id is null then
    return new;
  end if;

  select id into v_alee_owner_id from auth.users
  where lower(email) = 'aleeshopping2026@gmail.com' limit 1;

  if new.shop_id is null then
    v_seller_id := v_alee_owner_id;
    v_shop_name := 'ALEE SHOPPING';
  else
    select owner_id, shop_name into v_seller_id, v_shop_name
    from public.seller_shops where id = new.shop_id;
  end if;

  if to_regclass('public.seller_conversations') is null
     or to_regclass('public.seller_messages') is null then
    return new;
  end if;

  select coalesce(nullif(new.customer_name, ''), 'Buyer') into v_buyer_label;
  v_message := '🛒 New order #' || upper(left(replace(new.id::text, '-', ''), 8))
    || E'\nShop: ' || coalesce(v_shop_name, 'Shop')
    || E'\nCustomer: ' || new.customer_name
    || E'\nAddress: ' || new.customer_address
    || E'\nPhone: ' || new.customer_phone
    || E'\nItems: ' || coalesce((
      select string_agg(coalesce(item->>'name','Item') || ' × ' || coalesce(item->>'quantity','1'), ', ')
      from jsonb_array_elements(new.items) as item
    ), '')
    || E'\nTotal: LKR ' || to_char(new.total, 'FM999,999,999,990.00')
    || E'\nPayment: ' || new.payment_method
    || case when nullif(new.customer_note, '') is not null then E'\nNote: ' || new.customer_note else '' end;

  -- Notify the seller who owns this shop.
  if v_seller_id is not null and v_seller_id <> new.user_id then
    if new.shop_id is null then
      insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label)
      values (null, new.user_id, v_seller_id, v_buyer_label)
      on conflict (buyer_id) where shop_id is null do update set updated_at = now()
      returning id into v_conversation_id;
    else
      insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label)
      values (new.shop_id, new.user_id, v_seller_id, v_buyer_label)
      on conflict (shop_id,buyer_id) where shop_id is not null do update set updated_at = now()
      returning id into v_conversation_id;
    end if;

    insert into public.seller_messages (conversation_id, sender_id, body)
    values (v_conversation_id, new.user_id, left(v_message, 4000));
  end if;

  -- Also notify the ALEE SHOPPING owner unless they are already the seller.
  if v_alee_owner_id is not null
     and v_alee_owner_id <> new.user_id
     and v_alee_owner_id is distinct from v_seller_id then
    insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label)
    values (null, new.user_id, v_alee_owner_id, v_buyer_label)
    on conflict (buyer_id) where shop_id is null do update set updated_at = now()
    returning id into v_conversation_id;

    insert into public.seller_messages (conversation_id, sender_id, body)
    values (v_conversation_id, new.user_id, left(v_message, 4000));
  end if;

  return new;
end;
$$;

drop trigger if exists store_order_post_to_seller_chat on public.store_orders;
create trigger store_order_post_to_seller_chat
  after insert on public.store_orders
  for each row execute function public.post_order_to_seller_chat();

do $$ begin
  alter publication supabase_realtime add table public.store_orders;
exception when duplicate_object then null;
end $$;
