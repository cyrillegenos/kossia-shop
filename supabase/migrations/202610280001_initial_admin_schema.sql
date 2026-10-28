-- KOSSIA SHOP: initial schema for the admin dashboard.
-- Review this migration in Supabase SQL Editor before running it.
-- Security model: public visitors can read active products and submit orders;
-- only authenticated users listed as admins in public.profiles can manage products,
-- view orders, or update order status.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  price_xof integer not null check (price_xof >= 0),
  category text not null default 'Accessoires',
  image_url text not null default '',
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (char_length(trim(customer_name)) between 2 and 120),
  customer_phone text not null check (char_length(trim(customer_phone)) between 6 and 30),
  delivery_address text not null default '',
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  total_xof integer not null check (total_xof >= 0),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'preparing', 'shipped', 'completed', 'cancelled')),
  customer_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_active_category_idx on public.products(active, category);
create index if not exists orders_created_at_idx on public.orders(created_at desc);
create index if not exists orders_status_idx on public.orders(status);

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_admin = true
  );
$$;

revoke all on function public.is_current_user_admin() from public;
grant execute on function public.is_current_user_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

drop policy if exists "Admins can read profiles" on public.profiles;
create policy "Admins can read profiles"
on public.profiles for select to authenticated
using (public.is_current_user_admin() or id = (select auth.uid()));

drop policy if exists "Public can read active products" on public.products;
create policy "Public can read active products"
on public.products for select to anon, authenticated
using (active = true or public.is_current_user_admin());

drop policy if exists "Admins can insert products" on public.products;
create policy "Admins can insert products"
on public.products for insert to authenticated
with check (public.is_current_user_admin());

drop policy if exists "Admins can update products" on public.products;
create policy "Admins can update products"
on public.products for update to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Admins can delete products" on public.products;
create policy "Admins can delete products"
on public.products for delete to authenticated
using (public.is_current_user_admin());

drop policy if exists "Visitors can submit orders" on public.orders;
create policy "Visitors can submit orders"
on public.orders for insert to anon, authenticated
with check (
  char_length(trim(customer_name)) between 2 and 120
  and char_length(trim(customer_phone)) between 6 and 30
  and jsonb_typeof(items) = 'array'
  and total_xof >= 0
);

drop policy if exists "Admins can read orders" on public.orders;
create policy "Admins can read orders"
on public.orders for select to authenticated
using (public.is_current_user_admin());

drop policy if exists "Admins can update orders" on public.orders;
create policy "Admins can update orders"
on public.orders for update to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

-- Important setup:
-- 1) Create your first admin user through Supabase Authentication.
-- 2) Insert that user's UUID into public.profiles and set is_admin=true, using SQL Editor.
-- 3) Keep the Supabase service_role key secret; never put it in browser code or GitHub.
-- 4) Before accepting live orders, add server-side validation for item prices and totals.
