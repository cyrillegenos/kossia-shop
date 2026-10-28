-- KOSSIA SHOP: harden public order creation.
-- Checkout now uses create_public_order(), which validates products, quantities and totals
-- inside a SECURITY DEFINER function. Prevent direct table inserts from bypassing that logic.
revoke insert on table public.orders from anon, authenticated;

-- The public RPC is the only intended way for customers to submit orders.
-- Admin SELECT/UPDATE policies and authenticated dashboard access remain unchanged.
revoke all on function public.create_public_order(text, text, text, text, jsonb, text, text, text) from public;
grant execute on function public.create_public_order(text, text, text, text, jsonb, text, text, text) to anon, authenticated;
