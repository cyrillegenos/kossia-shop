# KOSSIA SHOP — Supabase setup for the admin

The storefront is currently a static site. This setup adds the database foundation for products, stock, orders, and administrator access.

## 1. Create a Supabase project
1. Open https://supabase.com/dashboard and sign in.
2. Choose **New project**.
3. Select your organization, give the project a name such as `kossia-shop`, choose a strong database password, and save it somewhere private.
4. Choose a region close to your customers when available, then create the project.

## 2. Create the database tables
1. Open the new project and choose **SQL Editor**.
2. Open the repository file `supabase/migrations/202610280001_initial_admin_schema.sql`.
3. Copy its SQL into the editor and run it.
4. Confirm that the `profiles`, `products`, and `orders` tables exist and that Row Level Security is enabled.

## 3. Create the first administrator
1. In Supabase, open **Authentication → Users** and create the administrator user with an email and a strong password.
2. Copy that user's UUID.
3. In SQL Editor, run the following after replacing `PASTE_AUTH_USER_UUID_HERE` with the actual UUID:

```sql
insert into public.profiles (id, display_name, is_admin)
values ('PASTE_AUTH_USER_UUID_HERE', 'KOSSIA SHOP Admin', true)
on conflict (id) do update set is_admin = true;
```

Do not share the password or UUID publicly.

## 4. Connect the Vercel project
The Vercel project currently has no environment variables. After the application integration is implemented, add the Supabase **Project URL** and **publishable/anon key** as the appropriate public variables in Vercel. Never put the `service_role` key in browser code, GitHub, or a public environment variable.

The exact variable names will be documented with the integration code. Do not guess them or add credentials until the code expects them.

## 5. Important safety notes
- RLS policies in the migration restrict product changes and order access to admins.
- The public order insert policy is only a foundation. Before taking real orders, the app must validate product IDs, prices, quantities, and totals server-side; otherwise a visitor could submit a manipulated total.
- Apply the SQL only to the intended KOSSIA SHOP Supabase project.
- This migration creates the database schema; it does not by itself connect the storefront or provide a finished admin interface.
