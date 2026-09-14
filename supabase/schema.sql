-- Hands On Moving Thrift Store
-- Reference schema matching the live Supabase project.
-- Project ref: fcgvrrrxzcqqzrqmwvmk
-- IMPORTANT: This is for source control/reference. The live project is already configured.

create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 200),
  description text not null default '',
  price numeric(10,2) not null default 0 check (price >= 0),
  category text not null default 'Other',
  condition text not null default 'Good',
  status text not null default 'available' check (status in ('available','sold','hidden','trash')),
  image_path text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;
alter table public.admin_users enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.admin_users to authenticated;

create or replace function public.is_admin()
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

grant execute on function public.is_admin() to anon, authenticated;

create policy "public can read available products"
on public.products for select
to anon, authenticated
using (status = 'available' or public.is_admin());

create policy "admins can insert products"
on public.products for insert
to authenticated
with check (public.is_admin() and created_by = (select auth.uid()));

create policy "admins can update products"
on public.products for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admins can delete products"
on public.products for delete
to authenticated
using (public.is_admin());

create policy "admins can see own admin row"
on public.admin_users for select
to authenticated
using (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images','product-images',true,10485760,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "public can view product images"
on storage.objects for select
to public
using (bucket_id = 'product-images');

create policy "admins can upload product images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'product-images' and public.is_admin());

create policy "admins can update product images"
on storage.objects for update
to authenticated
using (bucket_id = 'product-images' and public.is_admin())
with check (bucket_id = 'product-images' and public.is_admin());

create policy "admins can delete product images"
on storage.objects for delete
to authenticated
using (bucket_id = 'product-images' and public.is_admin());

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

-- One-time first-admin bootstrap support. The live database already has this.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.admin_bootstrap (
  id boolean primary key default true check (id = true),
  code_hash text not null,
  created_at timestamptz not null default now()
);

create or replace function public.claim_first_admin(p_code text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.admin_users) then
    raise exception 'An admin already exists';
  end if;

  select code_hash into v_hash
  from private.admin_bootstrap
  where id = true
  for update;

  if v_hash is null or encode(extensions.digest(convert_to(p_code, 'UTF8'), 'sha256'), 'hex') <> v_hash then
    raise exception 'Invalid bootstrap code';
  end if;

  insert into public.admin_users(user_id) values (v_uid);
  delete from private.admin_bootstrap where id = true;
  return true;
end;
$$;

revoke all on function public.claim_first_admin(text) from public, anon;
grant execute on function public.claim_first_admin(text) to authenticated;

-- The bootstrap code hash is deliberately NOT stored in source control.
