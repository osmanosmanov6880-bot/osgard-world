-- OSGARD HORIZON — real-money digital cosmetic entitlements.
-- INSTALL ONLY after selecting the correct Supabase project and UK Stripe merchant.
-- No credentials are stored in this migration. Catalog starts INACTIVE for safety.
create table if not exists public.omega_store_catalog (
  sku text primary key check (sku ~ '^[a-z][a-z0-9_]{2,50}$'),
  title text not null,
  description text not null default '',
  price_pence integer not null check (price_pence between 100 and 200000),
  currency text not null default 'gbp' check (currency = 'gbp'),
  stripe_price_id text unique check (stripe_price_id is null or stripe_price_id ~ '^price_[A-Za-z0-9]+$'),
  active boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.omega_store_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sku text not null references public.omega_store_catalog(sku),
  amount_pence integer not null check (amount_pence > 0),
  currency text not null default 'gbp' check (currency = 'gbp'),
  stripe_session_id text unique,
  stripe_payment_intent_id text unique,
  stripe_customer_id text,
  status text not null default 'pending' check (status in ('pending','paid','refunded','disputed','cancelled','expired')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create index if not exists omega_store_orders_uid_created_idx
  on public.omega_store_orders(user_id,created_at desc);
-- Prevent two simultaneous checkouts for the same one-time cosmetic.
create unique index if not exists omega_one_pending_checkout_per_sku
  on public.omega_store_orders(user_id,sku) where status='pending';

create table if not exists public.omega_store_entitlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  sku text not null references public.omega_store_catalog(sku),
  order_id uuid not null unique references public.omega_store_orders(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (user_id,sku)
);
create table if not exists public.omega_store_events (
  stripe_event_id text primary key,
  order_id uuid references public.omega_store_orders(id),
  event_kind text not null,
  processed_at timestamptz not null default now()
);

-- All public schema tables enforce row-level ownership; clients cannot mutate money.
alter table public.omega_store_catalog enable row level security;
alter table public.omega_store_orders enable row level security;
alter table public.omega_store_entitlements enable row level security;
alter table public.omega_store_events enable row level security;

revoke all on public.omega_store_catalog from anon, authenticated;
revoke all on public.omega_store_orders from anon, authenticated;
revoke all on public.omega_store_entitlements from anon, authenticated;
revoke all on public.omega_store_events from anon, authenticated;
grant select on public.omega_store_catalog to anon, authenticated;
grant select on public.omega_store_orders to authenticated;
grant select on public.omega_store_entitlements to authenticated;

drop policy if exists "omega_catalog_active_read" on public.omega_store_catalog;
create policy "omega_catalog_active_read" on public.omega_store_catalog
  for select to anon, authenticated using (active = true);
drop policy if exists "omega_orders_owner_read" on public.omega_store_orders;
create policy "omega_orders_owner_read" on public.omega_store_orders
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "omega_entitlements_owner_read" on public.omega_store_entitlements;
create policy "omega_entitlements_owner_read" on public.omega_store_entitlements
  for select to authenticated using (user_id = (select auth.uid()));
-- No client-readable events policy, and no client INSERT/UPDATE/DELETE policy.

-- Atomic, replay-safe server-only grant. Invoked only AFTER verified Stripe webhook,
-- correct paid amount/currency, matching order/session and live merchant verification.
create or replace function public.omega_grant_paid_order(
  p_order_id uuid, p_session_id text, p_payment_intent text,
  p_customer_id text, p_event_id text
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_order public.omega_store_orders%rowtype;
begin
  select * into v_order from public.omega_store_orders
    where id=p_order_id for update;
  if not found then raise exception 'Unknown order'; end if;
  if v_order.stripe_session_id is distinct from p_session_id then
    raise exception 'Session does not match order';
  end if;
  if v_order.status in ('refunded','disputed') then return false; end if;
  if exists (select 1 from public.omega_store_events where stripe_event_id=p_event_id)
  then return true; end if;
  if v_order.status not in ('pending','paid') then return false; end if;
  if p_payment_intent !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'Invalid Stripe payment intent';
  end if;
  insert into public.omega_store_entitlements(user_id,sku,order_id,revoked_at)
    values (v_order.user_id,v_order.sku,v_order.id,null)
    on conflict(user_id,sku) do update set
      order_id=excluded.order_id, granted_at=now(), revoked_at=null;
  update public.omega_store_orders set
    stripe_payment_intent_id=p_payment_intent,
    stripe_customer_id=p_customer_id,
    status='paid', paid_at=coalesce(paid_at,now())
    where id=v_order.id;
  insert into public.omega_store_events(stripe_event_id,order_id,event_kind)
    values (p_event_id,v_order.id,'payment_granted')
    on conflict(stripe_event_id) do nothing;
  return true;
end;
$$;

-- Full refund or dispute revokes ONLY the entitlement issued by that order.
-- A refund for an older purchase cannot revoke a later repurchase.
create or replace function public.omega_revoke_paid_order(
  p_order_id uuid, p_event_id text, p_reason text
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_order public.omega_store_orders%rowtype;
begin
  if p_reason not in ('refunded','disputed') then raise exception 'Invalid reason'; end if;
  select * into v_order from public.omega_store_orders where id=p_order_id for update;
  if not found then raise exception 'Unknown order'; end if;
  if exists (select 1 from public.omega_store_events where stripe_event_id=p_event_id)
  then return true; end if;
  update public.omega_store_orders set status=p_reason where id=p_order_id;
  update public.omega_store_entitlements set revoked_at=now()
    where order_id=p_order_id and revoked_at is null;
  insert into public.omega_store_events(stripe_event_id,order_id,event_kind)
    values(p_event_id,p_order_id,p_reason)
    on conflict(stripe_event_id) do nothing;
  return true;
end;
$$;

revoke all on function public.omega_grant_paid_order(uuid,text,text,text,text) from public,anon,authenticated;
revoke all on function public.omega_revoke_paid_order(uuid,text,text) from public,anon,authenticated;
grant execute on function public.omega_grant_paid_order(uuid,text,text,text,text) to service_role;
grant execute on function public.omega_revoke_paid_order(uuid,text,text) to service_role;

-- Suggested cosmetic-only GBP catalog; inactive until owner authorizes Stripe
-- LIVE price IDs and verifies seller identity, tax rules, refund policy and website.
insert into public.omega_store_catalog
  (sku,title,description,price_pence,currency,active)
values
  ('crimson_paint','Crimson GT Finish','Permanent crimson metallic car paint',299,'gbp',false),
  ('aurora_paint','Aurora GT Finish','Permanent turquoise pearlescent car paint',499,'gbp',false),
  ('founder_gold','Founders Gold Finish','Permanent founder gold car paint',999,'gbp',false)
on conflict(sku) do update set
  title=excluded.title,description=excluded.description;
