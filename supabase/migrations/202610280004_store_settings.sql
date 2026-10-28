-- KOSSIA SHOP: editable public store settings.
create table if not exists public.store_settings (
  id text primary key default 'main' check (id = 'main'),
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.store_settings enable row level security;
drop policy if exists "Public can read store settings" on public.store_settings;
create policy "Public can read store settings"
on public.store_settings for select to anon, authenticated
using (true);
drop policy if exists "Admins can insert store settings" on public.store_settings;
create policy "Admins can insert store settings"
on public.store_settings for insert to authenticated
with check (public.is_current_user_admin());
drop policy if exists "Admins can update store settings" on public.store_settings;
create policy "Admins can update store settings"
on public.store_settings for update to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());
insert into public.store_settings (id, settings)
values ('main', jsonb_build_object(
  'store_name', 'KOSSIA SHOP',
  'tagline', 'Ton style, ta signature.',
  'whatsapp', '2250777079611',
  'support_whatsapp', '2250141987202',
  'delivery_zones', 'Abidjan et environs, selon confirmation de la boutique',
  'delivery_time', 'Délai confirmé après validation de la commande',
  'delivery_fee_text', 'Frais communiqués avant confirmation',
  'payment_methods', 'Modalités de paiement confirmées par WhatsApp',
  'returns_policy', 'Contacte la boutique avant tout retour. Les conditions sont confirmées au moment de la commande.',
  'about_text', 'Une sélection de mode, beauté et accessoires pour affirmer ton style.',
  'instagram_url', '',
  'facebook_url', ''
))
on conflict (id) do nothing;
