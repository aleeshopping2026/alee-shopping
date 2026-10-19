-- ALEE SHOPPING group chats. Additive upgrade: keeps current conversations and messages.
-- Run after seller-chat-schema.sql has succeeded.

alter table public.seller_conversations
  add column if not exists is_group boolean not null default false;

-- Keep a readable author label on group messages. Direct chats do not need it.
alter table public.seller_messages
  add column if not exists sender_label text;

-- Keep the one-to-one ALEE inbox uniqueness rule while allowing multiple groups per owner.
drop index if exists public.seller_conversations_alee_buyer_unique;
create unique index if not exists seller_conversations_alee_buyer_unique
  on public.seller_conversations (buyer_id)
  where shop_id is null and is_group = false;

create table if not exists public.seller_chat_groups (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null unique references public.seller_conversations(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.seller_chat_group_members (
  group_id uuid not null references public.seller_chat_groups(id) on delete cascade,
  conversation_id uuid not null references public.seller_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id),
  unique (conversation_id, user_id)
);

create index if not exists seller_chat_group_members_user_idx
  on public.seller_chat_group_members (user_id, joined_at desc);
create index if not exists seller_chat_group_members_conversation_idx
  on public.seller_chat_group_members (conversation_id, user_id);

alter table public.seller_chat_groups enable row level security;
alter table public.seller_chat_group_members enable row level security;

-- RLS helpers use the signed-in user's identity and avoid exposing other users' memberships.
create or replace function public.is_seller_chat_group_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.seller_chat_group_members gm
    where gm.conversation_id = p_conversation_id and gm.user_id = auth.uid()
  );
$$;
revoke all on function public.is_seller_chat_group_member(uuid) from public, anon;
grant execute on function public.is_seller_chat_group_member(uuid) to authenticated;

drop policy if exists "Chat participants can read their conversations" on public.seller_conversations;
create policy "Chat participants can read their conversations" on public.seller_conversations
  for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id) or (is_group and public.is_seller_chat_group_member(id)));

drop policy if exists "Chat participants can read messages" on public.seller_messages;
create policy "Chat participants can read messages" on public.seller_messages
  for select to authenticated
  using (exists (
    select 1 from public.seller_conversations c
    where c.id = conversation_id
      and ((select auth.uid()) in (c.buyer_id, c.seller_id)
           or (c.is_group and public.is_seller_chat_group_member(c.id)))
  ));

drop policy if exists "Participants can send their own messages" on public.seller_messages;
create policy "Participants can send their own messages" on public.seller_messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.seller_conversations c
      where c.id = conversation_id
        and ((select auth.uid()) in (c.buyer_id, c.seller_id)
             or (c.is_group and public.is_seller_chat_group_member(c.id)))
        and (c.is_group or not exists (
          select 1 from public.seller_chat_blocks b
          where (b.user_id = (select auth.uid()) and b.blocked_user_id in (c.buyer_id,c.seller_id))
             or (b.blocked_user_id = (select auth.uid()) and b.user_id in (c.buyer_id,c.seller_id))
        ))
    )
  );

drop policy if exists "Participants can create their chat preferences" on public.seller_chat_preferences;
create policy "Participants can create their chat preferences" on public.seller_chat_preferences
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.seller_conversations c
      where c.id = conversation_id
        and ((select auth.uid()) in (c.buyer_id, c.seller_id)
             or (c.is_group and public.is_seller_chat_group_member(c.id)))
    )
  );
drop policy if exists "Users can update their own chat preferences" on public.seller_chat_preferences;
create policy "Users can update their own chat preferences" on public.seller_chat_preferences
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.seller_conversations c
    where c.id = conversation_id
      and ((select auth.uid()) in (c.buyer_id, c.seller_id)
           or (c.is_group and public.is_seller_chat_group_member(c.id)))
  ));

drop policy if exists "Group members can read their groups" on public.seller_chat_groups;
create policy "Group members can read their groups" on public.seller_chat_groups
  for select to authenticated using (public.is_seller_chat_group_member(conversation_id));
drop policy if exists "Users can read group membership" on public.seller_chat_group_members;
create policy "Users can read group membership" on public.seller_chat_group_members
  for select to authenticated using (
    user_id = (select auth.uid()) or public.is_seller_chat_group_member(conversation_id)
  );

grant select on public.seller_chat_groups, public.seller_chat_group_members to authenticated;

-- Create a group from people the current user has already chatted with.
-- The caller is added automatically; at least one other existing chat contact is required.
create or replace function public.create_seller_chat_group(p_name text, p_member_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := nullif(trim(p_name), '');
  v_members uuid[];
  v_first_other uuid;
  v_conversation_id uuid;
  v_group_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in is required to create a group.' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) > 80 then
    raise exception 'Enter a group name of 1 to 80 characters.' using errcode = '22023';
  end if;

  select array_agg(distinct selected.member_id order by selected.member_id)
    into v_members
  from unnest(coalesce(p_member_ids, array[]::uuid[]) || array[v_user_id]) as selected(member_id)
  where selected.member_id is not null;

  if coalesce(cardinality(v_members), 0) < 2 then
    raise exception 'Choose at least one chat contact.' using errcode = '22023';
  end if;
  if cardinality(v_members) > 50 then
    raise exception 'A group can have at most 50 members.' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(v_members) as selected(member_id)
    where selected.member_id <> v_user_id
      and not exists (
        select 1 from public.seller_conversations c
        where (c.buyer_id = v_user_id and c.seller_id = selected.member_id)
           or (c.seller_id = v_user_id and c.buyer_id = selected.member_id)
      )
  ) then
    raise exception 'Groups can include only people you have already chatted with.' using errcode = '22023';
  end if;

  select selected.member_id into v_first_other
  from unnest(v_members) as selected(member_id)
  where selected.member_id <> v_user_id
  order by selected.member_id
  limit 1;

  insert into public.seller_conversations (shop_id, buyer_id, seller_id, buyer_label, is_group)
  values (null, v_user_id, v_first_other, v_name, true)
  returning id into v_conversation_id;

  insert into public.seller_chat_groups (conversation_id, name, created_by)
  values (v_conversation_id, v_name, v_user_id)
  returning id into v_group_id;

  insert into public.seller_chat_group_members (group_id, conversation_id, user_id, role)
  select v_group_id, v_conversation_id, member_id,
         case when member_id = v_user_id then 'owner' else 'member' end
  from unnest(v_members) as selected(member_id);

  return v_conversation_id;
end;
$$;
revoke all on function public.create_seller_chat_group(text, uuid[]) from public, anon;
grant execute on function public.create_seller_chat_group(text, uuid[]) to authenticated;

-- Group members may read/upload attachments in the existing private chat bucket.
drop policy if exists "Chat participants can read chat files" on storage.objects;
create policy "Chat participants can read chat files" on storage.objects
  for select to authenticated using (
    bucket_id = 'seller-chat-files' and exists (
      select 1 from public.seller_conversations c
      where c.id = ((storage.foldername(name))[1])::uuid
        and ((select auth.uid()) in (c.buyer_id, c.seller_id)
             or (c.is_group and public.is_seller_chat_group_member(c.id)))
    )
  );
drop policy if exists "Chat participants can upload chat files" on storage.objects;
create policy "Chat participants can upload chat files" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'seller-chat-files'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and exists (
      select 1 from public.seller_conversations c
      where c.id = ((storage.foldername(name))[1])::uuid
        and ((select auth.uid()) in (c.buyer_id, c.seller_id)
             or (c.is_group and public.is_seller_chat_group_member(c.id)))
    )
  );

-- Group messages use the existing seller_messages table and realtime publication.
-- Existing private conversations/messages are retained unchanged.
