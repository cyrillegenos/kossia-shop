-- KOSSIA SHOP: structured product specifications for admin and storefront.
alter table public.products
  add column if not exists color text,
  add column if not exists size text,
  add column if not exists material text,
  add column if not exists brand text,
  add column if not exists sku text,
  add column if not exists specifications text;

create index if not exists products_sku_idx
  on public.products (sku)
  where sku is not null and length(trim(sku)) > 0;
