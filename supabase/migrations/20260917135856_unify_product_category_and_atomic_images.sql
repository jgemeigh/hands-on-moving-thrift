-- Keep the classification visitors already use, but expose it as one category.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'group_tag'
  ) then
    execute $migration$
      update public.products
      set category = coalesce(nullif(trim(group_tag), ''), nullif(trim(category), ''), 'Other')
    $migration$;
  end if;
end;
$$;

drop index if exists public.products_group_tag_idx;
alter table public.products drop column if exists group_tag;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.products'::regclass and conname = 'products_category_check'
  ) then
    alter table public.products
      add constraint products_category_check
      check (category in ('Clothing','Dishware','Toys','Decor','Holiday','Furniture','Books','Electronics','Jewelry','Kitchen','Linens','Tools','Collectibles','Home','Other'));
  end if;
end;
$$;
create index if not exists products_category_idx on public.products (category);

-- Email and phone are alternatives: at least one must be present.
alter table public.inquiries drop constraint if exists inquiries_email_check;
alter table public.inquiries drop constraint if exists inquiries_contact_method_check;
alter table public.inquiries
  add constraint inquiries_contact_method_check
  check (
    (email = '' or position('@' in email) > 1)
    and (email <> '' or phone <> '')
  );

-- Save the product and its ordered image references in one transaction.
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
set search_path = public
as $$
declare
  v_previous_status text;
begin
  if auth.uid() is null or not public.is_admin() then
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
