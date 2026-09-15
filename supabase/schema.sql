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
  group_tag text not null default 'Other' check (group_tag in ('Clothing','Dishware','Toys','Decor','Holiday','Furniture','Books','Electronics','Jewelry','Kitchen','Linens','Tools','Collectibles','Home','Other')),
  condition text not null default 'Good',
  status text not null default 'available' check (status in ('available','sold','hidden','trash')),
  status_effective_date date,
  status_changed_at timestamptz,
  status_updated_by uuid references auth.users(id) on delete set null,
  status_updated_by_email text,
  image_path text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.site_copy (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_path text not null,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (product_id, image_path)
);

alter table public.products enable row level security;
alter table public.admin_users enable row level security;
alter table public.site_copy enable row level security;
alter table public.product_images enable row level security;

create index if not exists products_group_tag_idx on public.products (group_tag);
create index if not exists products_status_effective_date_idx on public.products (status_effective_date);
create index if not exists products_status_changed_at_idx on public.products (status_changed_at);
create index if not exists product_images_product_order_idx on public.product_images (product_id, sort_order, created_at);

grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.admin_users to authenticated;
grant select on public.site_copy to anon, authenticated;
grant insert, update, delete on public.site_copy to authenticated;
grant select on public.product_images to anon, authenticated;
grant insert, update, delete on public.product_images to authenticated;

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

create or replace function public.grant_admin_by_email(p_email text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester uuid := auth.uid();
  v_target uuid;
begin
  if v_requester is null then
    raise exception 'Authentication required';
  end if;

  if not exists (select 1 from public.admin_users where user_id = v_requester) then
    raise exception 'Admin access required';
  end if;

  select id into v_target
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_target is null then
    raise exception 'No user found for that email';
  end if;

  insert into public.admin_users(user_id)
  values (v_target)
  on conflict (user_id) do nothing;

  return true;
end;
$$;

revoke all on function public.grant_admin_by_email(text) from public, anon;
grant execute on function public.grant_admin_by_email(text) to authenticated;

create or replace function public.set_user_password_by_email(p_email text, p_password text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester uuid := auth.uid();
  v_target auth.users%rowtype;
begin
  if v_requester is null then
    raise exception 'Authentication required';
  end if;

  if not exists (select 1 from public.admin_users where user_id = v_requester) then
    raise exception 'Admin access required';
  end if;

  if char_length(coalesce(p_password, '')) < 12 then
    raise exception 'Password must be at least 12 characters';
  end if;

  select * into v_target
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_target.id is null then
    raise exception 'No user found for that email';
  end if;

  update auth.users
  set
    encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    confirmation_token = '',
    recovery_token = '',
    updated_at = now()
  where id = v_target.id;

  insert into auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at,
    email
  )
  values (
    v_target.id::text,
    v_target.id,
    jsonb_build_object(
      'sub', v_target.id::text,
      'email', v_target.email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    null,
    now(),
    now(),
    v_target.email
  )
  on conflict (provider_id, provider) do update
  set
    identity_data = excluded.identity_data,
    email = excluded.email,
    updated_at = now();

  return true;
end;
$$;

revoke all on function public.set_user_password_by_email(text, text) from public, anon;
grant execute on function public.set_user_password_by_email(text, text) to authenticated;

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

create policy "public can read site copy"
on public.site_copy for select
to anon, authenticated
using (true);

create policy "admins can insert site copy"
on public.site_copy for insert
to authenticated
with check (public.is_admin());

create policy "admins can update site copy"
on public.site_copy for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admins can delete site copy"
on public.site_copy for delete
to authenticated
using (public.is_admin());

create policy "public can read available product images"
on public.product_images for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_images.product_id
      and (p.status = 'available' or public.is_admin())
  )
);

create policy "admins can insert product images"
on public.product_images for insert
to authenticated
with check (public.is_admin());

create policy "admins can update product images"
on public.product_images for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admins can delete product images"
on public.product_images for delete
to authenticated
using (public.is_admin());

insert into public.site_copy(key, value) values
  ('topbar', 'Fresh finds • Local pickup only • Inventory changes often'),
  ('brand_name', 'Hands On Moving'),
  ('brand_subtitle', 'Thrift Store'),
  ('nav_inventory', 'Inventory'),
  ('nav_about', 'About'),
  ('nav_new_finds', 'New Finds'),
  ('nav_contact', 'Contact'),
  ('store_phone', ''),
  ('header_promo', 'New finds added often • 728 S. 27th St.'),
  ('hero_eyebrow', 'Furniture • Decor • Clothing • Oddball treasures'),
  ('hero_title', 'Good stuff deserves another move.'),
  ('hero_body', 'Secondhand finds from moves, cleanouts, donations, and neighborhood pickups. Browse what is currently available, then contact or visit the store.'),
  ('hero_button', 'Browse inventory'),
  ('site_logo', 'assets/brand/hands-on-moving-thrift-logo.jpg'),
  ('site_hero_background', 'assets/shop/front-room.jpg'),
  ('site_ambient_left', 'assets/shop/mural-wall.jpg'),
  ('site_ambient_right', 'assets/shop/store-sign.jpg'),
  ('site_hero_card', 'assets/shop/store-sign.jpg'),
  ('hero_card_eyebrow', 'One-of-a-kind finds'),
  ('hero_card_title', 'See it? Come grab it.'),
  ('hero_card_body', 'No online checkout. Listings show currently available inventory.'),
  ('inventory_title', 'Current inventory'),
  ('inventory_subtitle', 'Live listings from the store.'),
  ('about_pickup_title', '📍 Local pickup'),
  ('about_pickup_body', 'Browse before making the trip.'),
  ('about_unique_title', '🪑 One-off inventory'),
  ('about_unique_body', 'Most pieces are unique. Once sold, they disappear from the public catalog.'),
  ('about_reuse_title', '♻️ Reuse first'),
  ('about_reuse_body', 'Useful items get another chance before disposal.'),
  ('store_hours_title', 'Hours'),
  ('store_hours', 'Hours coming soon. Call or message before visiting.'),
  ('visit_eyebrow', 'Visit the store'),
  ('visit_title', 'Stop by or ask first.'),
  ('visit_body', 'Inventory moves quickly, so use the form to ask about availability or request a short hold before making the trip.'),
  ('visit_address_label', 'Address'),
  ('visit_hours_label', 'Hours'),
  ('visit_contact_label', 'Contact'),
  ('directions_label', 'Get directions'),
  ('directions_url', 'https://www.google.com/maps/search/?api=1&query=728%20S.%2027th%20St.%20Lincoln%2C%20NE'),
  ('contact_title', 'Ask about an item'),
  ('contact_body', 'Send a quick note about availability or a possible hold. Include the listing name if you saw it in inventory.'),
  ('contact_email', 'Admin@handsonmoving.org'),
  ('inquiry_button', 'Send inquiry'),
  ('inquiry_success', 'Thanks. Your inquiry was sent.'),
  ('inquiry_error', 'Could not send the inquiry. Please call or email the store.'),
  ('footer_description', 'Online catalog for local secondhand inventory. No online transactions.'),
  ('footer_inventory_title', 'Inventory'),
  ('footer_inventory_link', 'Browse available items'),
  ('footer_contact_link', 'Ask about an item'),
  ('footer_store_title', 'Store'),
  ('footer_address', '728 S. 27th St., Lincoln, NE'),
  ('footer_store_note', 'Local pickup • No online checkout'),
  ('footer_admin_link', 'Admin')
on conflict (key) do nothing;

insert into public.product_images (product_id, image_path, sort_order, created_at)
select id, image_path, 0, created_at
from public.products
where image_path is not null
  and image_path <> ''
on conflict (product_id, image_path) do nothing;

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
