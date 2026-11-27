-- Admin-only private broadcast messages delivered into each user's ALEE inbox.
-- Run after seller-chat-schema.sql.

create table if not exists public.alee_private_broadcast_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete restrict,
  sender_id uuid not null references auth.users(id) on delete restrict,
  message_body text not null check (char_length(message_body) between 1 and 4000),
  recipient_count integer not null default 0 check (recipient_count >= 0),
  created_at timestamptz not null default now()
);

alter table public.alee_private_broadcast_log enable row level security;
revoke all on table public.alee_private_broadcast_log from public, anon, authenticated;

create or replace function public.alee_private_broadcast_audience_size()
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_sender_id uuid;
  v_count integer;
begin
  if v_actor_id is null or not exists (
    select 1 from auth.users u
    where u.id = v_actor_id
      and lower(coalesce(u.email, '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  ) then
    raise exception 'Only ALEE host accounts can check the broadcast audience.' using errcode = '42501';
  end if;

  select u.id into v_sender_id
    from auth.users u
    where lower(coalesce(u.email, '')) = 'aleeshopping2026@gmail.com'
    limit 1;
  v_sender_id := coalesce(v_sender_id, v_actor_id);

  select count(*)::integer into v_count
    from auth.users u
    where u.id <> v_sender_id
      and coalesce(u.is_anonymous, false) = false
      and not exists (
        select 1 from public.seller_chat_blocks b
        where (b.user_id = u.id and b.blocked_user_id = v_sender_id)
           or (b.user_id = v_sender_id and b.blocked_user_id = u.id)
      );
  return coalesce(v_count, 0);
end;
$$;

create or replace function public.send_alee_private_broadcast(p_body text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_sender_id uuid;
  v_recipient record;
  v_conversation_id uuid;
  v_sent integer := 0;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_actor_id is null or not exists (
    select 1 from auth.users u
    where u.id = v_actor_id
      and lower(coalesce(u.email, '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  ) then
    raise exception 'Only ALEE host accounts can send a private broadcast.' using errcode = '42501';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    raise exception 'Message must be between 1 and 4000 characters.' using errcode = '22023';
  end if;

  select u.id into v_sender_id
    from auth.users u
    where lower(coalesce(u.email, '')) = 'aleeshopping2026@gmail.com'
    limit 1;
  v_sender_id := coalesce(v_sender_id, v_actor_id);

  for v_recipient in
    select u.id
    from auth.users u
    where u.id <> v_sender_id
      and coalesce(u.is_anonymous, false) = false
      and not exists (
        select 1 from public.seller_chat_blocks b
        where (b.user_id = u.id and b.blocked_user_id = v_sender_id)
           or (b.user_id = v_sender_id and b.blocked_user_id = u.id)
      )
    order by u.created_at
  loop
    insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label)
    values (null, v_recipient.id, v_sender_id, 'ALEE Shopping')
    on conflict (buyer_id) where shop_id is null
      do update set seller_id = excluded.seller_id, buyer_label = 'ALEE Shopping', updated_at = now()
    returning id into v_conversation_id;

    insert into public.seller_messages (conversation_id, sender_id, body)
    values (v_conversation_id, v_sender_id, v_body);
    v_sent := v_sent + 1;
  end loop;

  insert into public.alee_private_broadcast_log (actor_id, sender_id, message_body, recipient_count)
  values (v_actor_id, v_sender_id, v_body, v_sent);

  return jsonb_build_object('recipient_count', v_sent);
end;
$$;

revoke all on function public.alee_private_broadcast_audience_size() from public, anon, authenticated;
revoke all on function public.send_alee_private_broadcast(text) from public, anon, authenticated;
grant execute on function public.alee_private_broadcast_audience_size() to authenticated;
grant execute on function public.send_alee_private_broadcast(text) to authenticated;
