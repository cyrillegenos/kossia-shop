-- KOSSIA SHOP: persistent orders and private customer status tracking.
-- Run this file in Supabase SQL Editor after migrations 001 and 002.
alter table public.orders
  add column if not exists tracking_code text,
  add column if not exists delivery_area text not null default '',
  add column if not exists payment_method text not null default 'À confirmer avec la boutique',
  add column if not exists map_link text not null default '';

update public.orders
set tracking_code = upper(encode(gen_random_bytes(5), 'hex'))
where tracking_code is null;

create unique index if not exists orders_tracking_code_uidx
  on public.orders(tracking_code);

create or replace function public.create_public_order(
  p_customer_name text,
  p_customer_phone text,
  p_delivery_area text,
  p_delivery_address text,
  p_items jsonb,
  p_payment_method text default 'À confirmer avec la boutique',
  p_customer_note text default '',
  p_map_link text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
  v_tracking_code text;
  v_item jsonb;
  v_product public.products%rowtype;
  v_quantity integer;
  v_total integer := 0;
  v_items jsonb := '[]'::jsonb;
  v_area text := left(trim(coalesce(p_delivery_area, '')), 120);
  v_address text := left(trim(coalesce(p_delivery_address, '')), 500);
  v_phone text := trim(coalesce(p_customer_phone, ''));
begin
  if char_length(trim(coalesce(p_customer_name, ''))) not between 2 and 120 then
    raise exception 'Vérifie le nom saisi (2 à 120 caractères).';
  end if;
  if char_length(v_phone) not between 6 and 30 then
    raise exception 'Vérifie le numéro de téléphone.';
  end if;
  if v_area = '' or v_address = '' then
    raise exception 'La commune et l’adresse de livraison sont obligatoires.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 30 then
    raise exception 'Le panier est vide ou contient trop de lignes.';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    if coalesce(v_item->>'id', '') = '' then
      raise exception 'Un article du panier est invalide.';
    end if;
    begin
      select * into strict v_product
      from public.products
      where id = (v_item->>'id')::uuid and active = true;
    exception when no_data_found or invalid_text_representation then
      raise exception 'Un article n’est plus disponible. Actualise la boutique et réessaie.';
    end;
    begin
      v_quantity := (v_item->>'quantity')::integer;
    exception when others then
      raise exception 'Une quantité du panier est invalide.';
    end;
    if v_quantity < 1 or v_quantity > 20 then
      raise exception 'La quantité doit être comprise entre 1 et 20.';
    end if;
    if v_product.stock < v_quantity then
      raise exception 'Stock insuffisant pour : %.', v_product.name;
    end if;
    v_total := v_total + (v_product.price_xof * v_quantity);
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', v_product.id,
      'name', v_product.name,
      'category', v_product.category,
      'price_xof', v_product.price_xof,
      'quantity', v_quantity
    ));
  end loop;

  v_tracking_code := upper(encode(gen_random_bytes(5), 'hex'));
  insert into public.orders (
    customer_name, customer_phone, delivery_area, delivery_address,
    items, total_xof, status, customer_note, payment_method, map_link, tracking_code
  ) values (
    trim(p_customer_name), v_phone, v_area,
    left(v_area || ' · ' || v_address, 650),
    v_items, v_total, 'pending', left(coalesce(p_customer_note, ''), 500),
    left(coalesce(nullif(trim(p_payment_method), ''), 'À confirmer avec la boutique'), 100),
    left(coalesce(p_map_link, ''), 1000), v_tracking_code
  ) returning id into v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'tracking_code', v_tracking_code,
    'status', 'pending',
    'total_xof', v_total
  );
end;
$$;

create or replace function public.get_public_order_status(
  p_tracking_code text,
  p_customer_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order
  from public.orders
  where tracking_code = upper(trim(coalesce(p_tracking_code, '')))
    and regexp_replace(customer_phone, '[^0-9]', '', 'g') =
        regexp_replace(coalesce(p_customer_phone, ''), '[^0-9]', '', 'g')
  limit 1;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  return jsonb_build_object(
    'found', true,
    'tracking_code', v_order.tracking_code,
    'status', v_order.status,
    'customer_name', v_order.customer_name,
    'delivery_area', v_order.delivery_area,
    'items', v_order.items,
    'total_xof', v_order.total_xof,
    'payment_method', v_order.payment_method,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at
  );
end;
$$;

revoke all on function public.create_public_order(text, text, text, text, jsonb, text, text, text) from public;
revoke all on function public.get_public_order_status(text, text) from public;
grant execute on function public.create_public_order(text, text, text, text, jsonb, text, text, text) to anon, authenticated;
grant execute on function public.get_public_order_status(text, text) to anon, authenticated;
