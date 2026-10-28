-- KOSSIA SHOP: promotions managed from the admin dashboard.
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 2 and 100),
  description text not null default '' check (char_length(description) <= 500),
  badge_text text not null default 'OFFRE' check (char_length(badge_text) <= 32),
  promo_code text not null default '' check (char_length(promo_code) <= 40),
  discount_type text not null default 'message' check (discount_type in ('percent','fixed','message')),
  discount_value numeric(10,2) not null default 0 check (discount_value >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint promotions_valid_dates check (starts_at is null or ends_at is null or ends_at > starts_at)
);
create index if not exists promotions_active_dates_idx on public.promotions(active, starts_at, ends_at);
alter table public.promotions enable row level security;
drop policy if exists "Public can read current promotions" on public.promotions;
create policy "Public can read current promotions" on public.promotions
for select to anon, authenticated
using (active = true and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()));
drop policy if exists "Admins can read all promotions" on public.promotions;
create policy "Admins can read all promotions" on public.promotions
for select to authenticated using (public.is_current_user_admin());
drop policy if exists "Admins can insert promotions" on public.promotions;
create policy "Admins can insert promotions" on public.promotions
for insert to authenticated with check (public.is_current_user_admin());
drop policy if exists "Admins can update promotions" on public.promotions;
create policy "Admins can update promotions" on public.promotions
for update to authenticated using (public.is_current_user_admin()) with check (public.is_current_user_admin());
drop policy if exists "Admins can delete promotions" on public.promotions;
create policy "Admins can delete promotions" on public.promotions
for delete to authenticated using (public.is_current_user_admin());
