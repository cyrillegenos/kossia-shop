-- KOSSIA SHOP: individual customer accounts (email/password), private profile, favorites and order history.
alter table public.orders
  add column if not exists customer_user_id uuid references auth.users(id) on delete set null;

create index if not exists orders_customer_user_id_created_idx
  on public.orders(customer_user_id, created_at desc);

create or replace function public.attach_order_customer_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.customer_user_id := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists orders_attach_customer_account on public.orders;
create trigger orders_attach_customer_account
before insert on public.orders
for each row execute function public.attach_order_customer_account();

create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  delivery_area text not null default '',
  delivery_address text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;
drop policy if exists "Customers read own profile" on public.customer_profiles;
create policy "Customers read own profile" on public.customer_profiles
for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Customers create own profile" on public.customer_profiles;
create policy "Customers create own profile" on public.customer_profiles
for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Customers update own profile" on public.customer_profiles;
create policy "Customers update own profile" on public.customer_profiles
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.customer_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
alter table public.customer_favorites enable row level security;
drop policy if exists "Customers read own favorites" on public.customer_favorites;
create policy "Customers read own favorites" on public.customer_favorites
for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Customers add own favorites" on public.customer_favorites;
create policy "Customers add own favorites" on public.customer_favorites
for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Customers remove own favorites" on public.customer_favorites;
create policy "Customers remove own favorites" on public.customer_favorites
for delete to authenticated using (auth.uid() = user_id);

create or replace function public.get_my_customer_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Connecte-toi pour consulter tes commandes.';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'tracking_code', o.tracking_code,
      'status', o.status,
      'items', o.items,
      'total_xof', o.total_xof,
      'delivery_area', o.delivery_area,
      'payment_method', o.payment_method,
      'created_at', o.created_at,
      'updated_at', o.updated_at
    ) order by o.created_at desc)
    from public.orders o
    where o.customer_user_id = auth.uid()
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.get_my_customer_orders() from public;
grant execute on function public.get_my_customer_orders() to authenticated;
