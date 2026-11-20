-- Send newly created seller products to the built-in ALEE Messages inbox.
-- Run after seller-marketplace-schema.sql, seller-chat-schema.sql, and
-- seller-group-chat-schema.sql. Product edits do not create a new message.

create or replace function public.notify_alee_new_seller_product(p_product_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_admin_id uuid;
  v_conversation_id uuid;
  v_shop_name text;
  v_product_name text;
  v_price numeric;
  v_currency_code text;
  v_category text;
  v_description text;
  v_features text[];
  v_sizes text[];
  v_image_urls text[];
  v_message text;
begin
  if auth.uid() is null then
    raise exception 'Sign in before sending a product submission.';
  end if;

  select s.shop_name, p.name, p.price, s.currency_code, p.category_label,
         p.description, p.features, p.sizes, p.image_urls
    into v_shop_name, v_product_name, v_price, v_currency_code, v_category,
         v_description, v_features, v_sizes, v_image_urls
  from public.seller_products p
  join public.seller_shops s on s.id = p.shop_id
  where p.id = p_product_id and p.owner_id = auth.uid();

  if not found then
    raise exception 'That product does not belong to your shop.';
  end if;

  select id into v_admin_id
  from auth.users
  where lower(email) = 'aleeshopping2026@gmail.com'
  limit 1;

  if v_admin_id is null then
    raise exception 'The ALEE Messages account is not configured.';
  end if;

  -- The site owner does not need to open a chat with their own account.
  if v_admin_id = auth.uid() then
    return false;
  end if;

  v_message := '📦 New shop item submission'
    || E'\nShop: ' || coalesce(v_shop_name, 'Shop')
    || E'\nItem: ' || coalesce(v_product_name, 'Item')
    || E'\nPrice: ' || coalesce(v_currency_code, 'LKR') || ' ' || to_char(v_price, 'FM999,999,999,990.00')
    || E'\nCategory: ' || coalesce(v_category, '—')
    || E'\nDescription: ' || coalesce(v_description, '—')
    || E'\nKey features: ' || coalesce(array_to_string(v_features, ', '), '—')
    || E'\nSizes: ' || coalesce(array_to_string(v_sizes, ', '), '—')
    || E'\nPhotos: ' || coalesce(cardinality(v_image_urls), 0)::text
    || case when coalesce(cardinality(v_image_urls), 0) > 0 then E'\nMain photo: ' || v_image_urls[1] else '' end
    || E'\nProduct link: https://www.aleeshopping.com/index.html?product='
    || (1000000000 + p_product_id)::text;

  insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label, is_group)
  values (null, auth.uid(), v_admin_id, coalesce(v_shop_name, 'Shop'), false)
  on conflict (buyer_id) where shop_id is null and is_group = false
  do update set updated_at = now(), last_message_at = now(), buyer_label = excluded.buyer_label
  returning id into v_conversation_id;

  insert into public.seller_messages (conversation_id, sender_id, body)
  values (v_conversation_id, auth.uid(), left(v_message, 4000));

  return true;
end;
$$;

revoke all on function public.notify_alee_new_seller_product(bigint) from public, anon;
grant execute on function public.notify_alee_new_seller_product(bigint) to authenticated;

notify pgrst, 'reload schema';
