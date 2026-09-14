# Hands On Moving Thrift Store

Catalog-only thrift store website for Hands On Moving.

## Current state
- Public inventory catalog
- Search and category filters
- Item detail modal
- Prototype admin UI for add/edit/sold/hidden/trash/delete
- No online checkout or transactions
- Current prototype inventory is browser-local only

## Planned production stack
- GitHub: source control
- Netlify: hosting and auto-deploys
- Supabase: shared inventory, image storage, admin authentication, Row Level Security

## Next steps
1. Push this project to GitHub.
2. Connect GitHub repo to Netlify.
3. Create Supabase project.
4. Replace localStorage inventory with Supabase.
5. Secure /admin with Supabase Auth and RLS.
