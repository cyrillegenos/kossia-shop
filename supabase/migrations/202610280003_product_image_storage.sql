-- KOSSIA SHOP: public product images, writable only by admins.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "Public can view product images" on storage.objects;
create policy "Public can view product images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'product-images');

drop policy if exists "Admins can upload product images" on storage.objects;
create policy "Admins can upload product images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_current_user_admin()
);

drop policy if exists "Admins can update product images" on storage.objects;
create policy "Admins can update product images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_current_user_admin()
)
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_current_user_admin()
);

drop policy if exists "Admins can delete product images" on storage.objects;
create policy "Admins can delete product images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.is_current_user_admin()
);
