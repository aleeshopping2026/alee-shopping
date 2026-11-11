-- Run after seller-chat-schema.sql and seller-group-chat-schema.sql.
-- These tables associate a logged-in ALEE account with its own OneSignal browser subscription.
create table if not exists public.alee_push_subscriptions (
  subscription_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists alee_push_subscriptions_user_idx
  on public.alee_push_subscriptions(user_id);

alter table public.alee_push_subscriptions enable row level security;
revoke all on public.alee_push_subscriptions from anon, authenticated;
grant select on public.alee_push_subscriptions to authenticated;

drop policy if exists "Users can view their own ALEE push subscriptions"
  on public.alee_push_subscriptions;
create policy "Users can view their own ALEE push subscriptions"
  on public.alee_push_subscriptions for select to authenticated
  using (user_id = (select auth.uid()));

-- Only the verified Edge Function (service role) can register these identifiers.
-- Browsers cannot insert or change another user's subscription mapping.

create table if not exists public.alee_chat_push_dispatches (
  message_id bigint primary key references public.seller_messages(id) on delete cascade,
  status text not null default 'sending'
    check (status in ('sending','sent','skipped')),
  onesignal_message_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.alee_chat_push_dispatches enable row level security;
revoke all on public.alee_chat_push_dispatches from anon, authenticated;
grant all on public.alee_push_subscriptions to service_role;
grant all on public.alee_chat_push_dispatches to service_role;

-- ALEE notification campaign images are public only so browser push services can fetch them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('alee-push-images', 'alee-push-images', true, 10485760,
  array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can read ALEE notification images" on storage.objects;
create policy "Anyone can read ALEE notification images"
  on storage.objects for select using (bucket_id = 'alee-push-images');

drop policy if exists "Only ALEE main admin can upload notification images" on storage.objects;
create policy "Only ALEE main admin can upload notification images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'alee-push-images'
    and lower(coalesce((select auth.jwt() ->> 'email'),'')) = 'aleeshopping2026@gmail.com');