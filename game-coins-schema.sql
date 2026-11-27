-- ALEE Games: private user wallet and one fixed reward per game per UTC day.
-- Users can read their own wallet; only the guarded RPC can add coins.

create table if not exists public.alee_game_coin_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.alee_game_coin_claims (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  game_key text not null,
  coins integer not null default 1 check (coins = 1),
  claimed_on date not null default (timezone('utc', now())::date),
  created_at timestamptz not null default now(),
  constraint alee_game_coin_claims_once_per_day unique (user_id, game_key, claimed_on)
);

alter table public.alee_game_coin_claims
  drop constraint if exists alee_game_coin_claims_game_key_check;
alter table public.alee_game_coin_claims
  add constraint alee_game_coin_claims_game_key_check
  check (game_key in ('alee_2048', 'alee_memory_match', 'alee_snake', 'alee_panda_delivery'));

alter table public.alee_game_coin_wallets enable row level security;
alter table public.alee_game_coin_claims enable row level security;

drop policy if exists "Users read own ALEE game coin wallet" on public.alee_game_coin_wallets;
create policy "Users read own ALEE game coin wallet"
  on public.alee_game_coin_wallets for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Users read own ALEE game coin claims" on public.alee_game_coin_claims;
create policy "Users read own ALEE game coin claims"
  on public.alee_game_coin_claims for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.alee_game_coin_wallets from anon, authenticated;
revoke all on table public.alee_game_coin_claims from anon, authenticated;
grant select on table public.alee_game_coin_wallets to authenticated;
grant select on table public.alee_game_coin_claims to authenticated;

create or replace function public.claim_alee_game_coin(p_game_key text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim_id bigint;
  v_balance integer;
  v_today date := timezone('utc', now())::date;
begin
  if v_user_id is null then
    raise exception 'You must sign in to earn game coins.' using errcode = '28000';
  end if;

  if p_game_key is null or p_game_key not in ('alee_2048', 'alee_memory_match', 'alee_snake', 'alee_panda_delivery') then
    raise exception 'Unknown ALEE game.' using errcode = '22023';
  end if;

  insert into public.alee_game_coin_wallets (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  insert into public.alee_game_coin_claims (user_id, game_key, coins, claimed_on)
  values (v_user_id, p_game_key, 1, v_today)
  on conflict (user_id, game_key, claimed_on) do nothing
  returning id into v_claim_id;

  if v_claim_id is not null then
    update public.alee_game_coin_wallets
      set balance = balance + 1, updated_at = now()
      where user_id = v_user_id
      returning balance into v_balance;
    return jsonb_build_object('awarded', 1, 'balance', v_balance, 'already_claimed', false);
  end if;

  select balance into v_balance
    from public.alee_game_coin_wallets
    where user_id = v_user_id;
  return jsonb_build_object('awarded', 0, 'balance', coalesce(v_balance, 0), 'already_claimed', true);
end;
$$;

revoke all on function public.claim_alee_game_coin(text) from public, anon, authenticated;
grant execute on function public.claim_alee_game_coin(text) to authenticated;
