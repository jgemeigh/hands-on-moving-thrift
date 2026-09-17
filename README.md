# Hands On Moving Thrift Store

Static Netlify storefront backed by Supabase.

## Production pieces
- Public catalog at `/`
- Admin at `/admin/`
- Supabase Auth for email/password login
- Supabase Postgres for product listings
- Supabase Storage bucket `product-images`
- Row Level Security: public read of available products, admin-only writes
- One unified product category used by both admin and storefront filtering
- Transactional product/photo-reference saves through `save_product_with_images`
- Inquiry delivery address controlled by `contact_email` in Admin > TEXT

## First admin setup
1. Open `/admin/`.
2. Create an account with the email/password you actually want to use.
3. Confirm the email if Supabase asks you to.
4. Sign in.
5. Enter the one-time bootstrap code supplied during deployment.
6. After it succeeds, the bootstrap code is deleted server-side and cannot be reused.

Public signup is not exposed in the admin UI. Existing admins send admin invite emails from `/admin/`.

Signed-in admins can request an email change from the Account panel in `/admin/`. Supabase may require confirmation from both the current and new email addresses depending on the project's Secure email change setting.

Signed-in admins can change their password from the Account panel in `/admin/`.

After the first bootstrap, existing admins can send a magic-link admin invite from `/admin/` by entering that user's email in the Admin access panel. The database function `public.grant_admin_by_email(text)` must exist in Supabase for this control to work.

Never put a Supabase secret/service-role key in this repository. The publishable key in the frontend is intentionally public and protected by RLS.

## Supabase Auth redirect configuration
In Supabase Dashboard > Authentication > URL Configuration:
- Site URL: `https://hands-on-moving-thrift.netlify.app`
- Redirect URLs: `https://hands-on-moving-thrift.netlify.app/admin/`

If confirmation emails redirect to `localhost:3000`, this Supabase Auth setting still needs to be changed in the dashboard.
