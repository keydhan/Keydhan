# KeyDhan V30 deployment and verification

## Important status
This branch contains a CMS/API implementation and admin pages. It is not live until the Worker is deployed and the branch is published through the configured Pages deployment pipeline. Do not merge until the checklist below is complete.

## 1. Cloudflare KV
Create or select a KV namespace in the same Cloudflare account. Replace `REPLACE_WITH_YOUR_KEYDHAN_DB_ID` in `wrangler.toml` with that namespace ID. The Worker uses this namespace for properties, leads, loan offers, website content, and settings. If you want a clean start, create a new namespace rather than deleting existing data.

## 2. Worker secret
Configure a strong random `ADMIN_API_KEY` as a Cloudflare Worker secret (not in source code). Admin pages ask for this key and keep it in browser session storage. Never commit the key into GitHub or put it in public HTML.

## 3. Deploy Worker
Deploy `worker.js` using Wrangler or the Cloudflare dashboard. Bind the KV namespace as `KEYDHAN_DB`, set the secret, and route the Worker to `admin-api.keydhan.com/*`. Verify `https://admin-api.keydhan.com/api/health` returns JSON with version 30 and status online.

## 4. Publish static website
Publish the branch through the existing Cloudflare Pages/GitHub Pages pipeline only after the Worker is ready. Confirm that the custom domain still points to the correct Pages project. Do not assume branch deployment is configured automatically.

## 5. Required smoke tests
- Open `/admin/`, enter the Worker secret in the admin key prompt.
- Dashboard shows counts rather than dashes.
- Add a test property; confirm it appears in admin and on public `/properties.html` when published.
- Edit the test property, mark draft, publish again, then delete it.
- Submit a test enquiry from the public contact form; verify it appears in Leads and can change status.
- Create, edit, publish, and delete a test loan offer.
- Save website page content and settings, reload, and verify the values persist.
- Test on desktop and mobile, then remove test records.

## Notes and limitations
- This first CMS release exposes editable home headings, hero image, services list, property heading, contact heading, footer text, about copy and SEO text through Page Content. Additional text or layout elements on other pages need to be explicitly wired to CMS fields before they become editable.
- Images are referenced by URL; direct uploads need R2 upload integration and policy configuration.
- The Worker stores data in KV; KV is suitable for this lightweight CMS, but large relational workloads may require D1.
- The admin API uses a shared secret, not a full user/role system. Protect `/admin/*` with Cloudflare Access as an additional layer.
- Validate CORS origins, rate limits, backup/restore, and error handling before advertising this as production-ready.
