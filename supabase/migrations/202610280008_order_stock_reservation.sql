-- KOSSIA SHOP: reserve stock atomically when a public order is created.
-- If an order is cancelled, return its reserved quantities to stock.
-- Reopening a cancelled order reserves stock again.
alter table public.orders
  add column if not exists stock_reserved boolean not null default false;

create or replace function public.manage_order_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_updated_id uuid;
begin
  if tg_op = 'INSERT' then
    for v_item in select value from jsonb_array_elements(new.items)
    loop
      begin
        v_product_id := (v_item->>'id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;
      exception when others then
        raise exception 'Une ligne de commande est invalide.';
      end;

      if v_quantity is null or v_quantity < 1 or v_quantity > 20 then
        raise exception 'Une quantité de commande est invalide.';
      end if;

      update public.products
      set stock = stock - v_quantity
      where id = v_product_id
        and active = true
        and stock >= v_quantity
      returning id into v_updated_id;

      if v_updated_id is null then
        raise exception 'Stock insuffisant pour un article de cette commande.';
      end if;
      v_updated_id := null;
    end loop;

    new.stock_reserved := true;
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'cancelled' and old.stock_reserved then
      for v_item in select value from jsonb_array_elements(old.items)
      loop
        v_product_id := (v_item->>'id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;
        update public.products
        set stock = stock + v_quantity
        where id = v_product_id;
      end loop;
      new.stock_reserved := false;

    elsif old.status = 'cancelled' and new.status <> 'cancelled' and not old.stock_reserved then
      for v_item in select value from jsonb_array_elements(new.items)
      loop
        v_product_id := (v_item->>'id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;

        update public.products
        set stock = stock - v_quantity
        where id = v_product_id
          and active = true
          and stock >= v_quantity
        returning id into v_updated_id;

        if v_updated_id is null then
          raise exception 'Stock insuffisant pour réactiver cette commande.';
        end if;
        v_updated_id := null;
      end loop;
      new.stock_reserved := true;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists orders_manage_stock on public.orders;
create trigger orders_manage_stock
before insert or update of status on public.orders
for each row execute function public.manage_order_stock();
