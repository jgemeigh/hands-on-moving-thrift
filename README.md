# Hands On Moving Thrift Store

Static Netlify storefront backed by Supabase.

## Production pieces
- Public catalog at `/`
- Admin at `/admin/`
- Supabase Auth for email/password login
- Supabase Postgres for product listings
- Supabase Storage bucket `product-images`
- Row Level Security: public read of available products, admin-only writes

## First admin setup
1. Open `/admin/`.
2. Create an account with the email/password you actually want to use.
3. Confirm the email if Supabase asks you to.
4. Sign in.
5. Enter the one-time bootstrap code supplied during deployment.
6. After it succeeds, the bootstrap code is deleted server-side and cannot be reused.

If the email account is stuck as pending, use the admin page's "Resend confirmation email" button or delete the unconfirmed user in Supabase Dashboard > Authentication > Users, then create the account again.

Signed-in admins can request an email change from the Account panel in `/admin/`. Supabase may require confirmation from both the current and new email addresses depending on the project's Secure email change setting.

Never put a Supabase secret/service-role key in this repository. The publishable key in the frontend is intentionally public and protected by RLS.

## Supabase Auth redirect configuration
In Supabase Dashboard > Authentication > URL Configuration:
- Site URL: `https://hands-on-moving-thrift.netlify.app`
- Redirect URLs: `https://hands-on-moving-thrift.netlify.app/admin/`

If confirmation emails redirect to `localhost:3000`, this Supabase Auth setting still needs to be changed in the dashboard.
