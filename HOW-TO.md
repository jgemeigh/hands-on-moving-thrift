# Hands On Moving Thrift Store: How-To Guide

The public site is https://hands-on-moving-thrift.netlify.app. The admin area is
https://hands-on-moving-thrift.netlify.app/admin/.

## What the site does

- Shows available inventory and full-size photo galleries.
- Lets shoppers filter inventory by category.
- Accepts questions and manual hold requests. A request is not a guaranteed hold.
- Emails inquiry details to the address set in **Admin > TEXT**.
- Keeps a second copy of every inquiry in **Admin > INQUIRIES**.
- Lets admins add, edit, hide, sell, trash, restore, and delete listings.
- Records the date and admin when a listing's status changes.
- Exports all inventory, including sold, hidden, and trashed items, as a CSV.
- Lets admins update website wording, store details, logo, and storefront images.

## Sign in

1. Open the admin address above.
2. Enter your admin email and password, then select **Sign in**.
3. When finished on a shared device, open **ACCOUNT** and select **Sign out**.

## Daily routine

1. Open **INQUIRIES** and select **Refresh**.
2. Check the store email inbox for new inquiries.
3. Reply from email so the customer's reply returns to the store inbox.
4. In **INQUIRIES**, mark handled messages **Responded**.
5. Under **LISTINGS**, update anything sold, unavailable, or newly added.
6. Quickly check the public Inventory page to make sure it looks current.

Email is the easiest communication tool. The inquiry dashboard is the store's
record and backup. Do not delete an inquiry until it has been answered and is no
longer useful.

## Add a listing

1. Open **LISTINGS** and select **New listing**.
2. Enter a clear title, price, category, condition, and short description.
3. Select the plus photo tile and choose one or more photos.
4. Check every preview before saving. Put the clearest overall photo first.
5. Leave the status as **Available** and select **Save listing**.
6. Check the listing once on the public Inventory page.

Use well-lit photos and avoid near-duplicates. The site resizes new photos to
reduce storage and loading time.

## Edit a listing

1. Find the item under **LISTINGS**.
2. Select **Edit**.
3. Change the information or photos.
4. Select **Save listing**.

Select **Cancel edit** to discard unsaved changes.

## Per-inquiry routine

1. Read the full message in the store email or **INQUIRIES**.
2. Check the listing and physically confirm the item is still available.
3. Reply to the customer by email or phone.
4. Only promise a manual hold when store staff agree. The website does not reserve
   inventory or take payment.
5. Mark the entry **Reviewed** if more work is needed, or **Responded** after answering.
6. Delete it only when the conversation is finished and the record is no longer needed.

If email delivery fails, the inquiry should still appear in the dashboard. The
email destination is under **TEXT > Inquiry recipient email**. A new destination
must confirm FormSubmit once before forwarding works.

## Per-sale routine

1. Find the item under **LISTINGS > Available**.
2. Select **Sold**.
3. Open **Sold** and confirm the sale date. Select **Edit** to correct the date.
4. Keep sold records for inventory history; do not permanently delete them during
   normal cleanup.
5. If the sale followed an inquiry, mark that inquiry **Responded**.

Use **Hidden** when an item should temporarily disappear from the public site. Use
**Trash** for a discarded or mistakenly created item. **Delete forever** removes
the listing and its stored photos and cannot be undone.

## Monthly routine

1. Open **LISTINGS** and select **Export CSV**. Keep the download as that month's
   inventory backup.
2. Review Available, Sold, Hidden, and Trash for stale or incorrect entries.
3. Check that hours, phone, address, and inquiry email are current under **TEXT**.
4. Submit one test inquiry from the public site. Confirm it reaches both the email
   inbox and **INQUIRIES**, then mark it responded and delete the test.
5. Under **ACCOUNT**, confirm only intended staff have admin access.
6. Under **IMAGES**, replace dated promotional photography when needed.

## Website text and images

- **TEXT** controls headings, descriptions, hours, phone, address, inquiry wording,
  privacy wording, and the inquiry delivery email.
- **IMAGES** controls the logo, hero image, and decorative storefront images.
- After saving, reload the public site and check it on a phone.
- Do not change the inquiry email casually. Every new FormSubmit destination must
  complete its one-time confirmation email.

## Accounts and passwords

- **Change email** sends confirmation messages before the change completes.
- **Change password** changes your own password.
- **Invite admin** emails another person and grants access after the account exists.
- **Set temporary password** is for a stuck admin. Share it privately and have that
  person change it immediately after signing in.
- Give each admin a separate login rather than sharing one account.

## When something looks wrong

- Missing inquiry email: check **INQUIRIES**, then verify the recipient under **TEXT**.
- Item still public after sale: reload and confirm it is under Sold, not Available.
- Bad photo: edit the listing, remove the photo, add it again, and save.
- Confirmation link opens localhost: Supabase Auth URL settings need maintainer attention.
- Do not run SQL or change Netlify or Supabase settings during normal store operation.
  Contact the site maintainer instead.
