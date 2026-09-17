create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users a where a.user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to anon, authenticated;

alter policy "public can read available products" on public.products
  using (status = 'available' or private.is_admin());
alter policy "admins can insert products" on public.products
  with check (private.is_admin() and created_by = (select auth.uid()));
alter policy "admins can update products" on public.products
  using (private.is_admin()) with check (private.is_admin());
alter policy "admins can delete products" on public.products using (private.is_admin());

alter policy "admins can insert site copy" on public.site_copy with check (private.is_admin());
alter policy "admins can update site copy" on public.site_copy
  using (private.is_admin()) with check (private.is_admin());
alter policy "admins can delete site copy" on public.site_copy using (private.is_admin());

alter policy "admins can read inquiries" on public.inquiries using (private.is_admin());
alter policy "admins can update inquiries" on public.inquiries
  using (private.is_admin()) with check (private.is_admin());
alter policy "admins can delete inquiries" on public.inquiries using (private.is_admin());

alter policy "public can read available product images" on public.product_images
  using (exists (
    select 1 from public.products p
    where p.id = product_images.product_id
      and (p.status = 'available' or private.is_admin())
  ));
alter policy "admins can insert product images" on public.product_images with check (private.is_admin());
alter policy "admins can update product images" on public.product_images
  using (private.is_admin()) with check (private.is_admin());
alter policy "admins can delete product images" on public.product_images using (private.is_admin());

alter policy "admins can upload product images" on storage.objects
  with check (bucket_id = 'product-images' and private.is_admin());
alter policy "admins can update product images" on storage.objects
  using (bucket_id = 'product-images' and private.is_admin())
  with check (bucket_id = 'product-images' and private.is_admin());
alter policy "admins can delete product images" on storage.objects
  using (bucket_id = 'product-images' and private.is_admin());

create or replace function public.save_product_with_images(
  p_id uuid,
  p_title text,
  p_price numeric,
  p_category text,
  p_condition text,
  p_status text,
  p_description text,
  p_status_effective_date date,
  p_image_paths text[]
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_previous_status text;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required';
  end if;

  select status into v_previous_status
  from public.products
  where id = p_id;

  if found then
    update public.products
    set title = p_title,
        price = p_price,
        category = p_category,
        condition = p_condition,
        status = p_status,
        description = coalesce(p_description, ''),
        image_path = p_image_paths[1],
        status_effective_date = case when p_status = 'available' then null else p_status_effective_date end,
        status_changed_at = case when v_previous_status is distinct from p_status then now() else status_changed_at end,
        status_updated_by = case when v_previous_status is distinct from p_status then auth.uid() else status_updated_by end,
        status_updated_by_email = case when v_previous_status is distinct from p_status then auth.jwt() ->> 'email' else status_updated_by_email end
    where id = p_id;
  else
    insert into public.products (
      id, title, price, category, condition, status, description, image_path,
      status_effective_date, status_changed_at, status_updated_by,
      status_updated_by_email, created_by
    ) values (
      p_id, p_title, p_price, p_category, p_condition, p_status,
      coalesce(p_description, ''), p_image_paths[1],
      case when p_status = 'available' then null else p_status_effective_date end,
      now(), auth.uid(), auth.jwt() ->> 'email', auth.uid()
    );
  end if;

  delete from public.product_images where product_id = p_id;
  insert into public.product_images (product_id, image_path, sort_order)
  select p_id, image_path, (ord - 1)::integer
  from unnest(coalesce(p_image_paths, array[]::text[])) with ordinality as paths(image_path, ord);

  return p_id;
end;
$$;

revoke all on function public.save_product_with_images(uuid,text,numeric,text,text,text,text,date,text[]) from public, anon;
grant execute on function public.save_product_with_images(uuid,text,numeric,text,text,text,text,date,text[]) to authenticated;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products
for each row execute function private.set_updated_at();

drop trigger if exists inquiries_set_updated_at on public.inquiries;
create trigger inquiries_set_updated_at before update on public.inquiries
for each row execute function private.set_updated_at();

revoke all on function private.set_updated_at() from public, anon, authenticated;
drop function if exists public.set_updated_at();
drop function if exists public.is_admin();

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
