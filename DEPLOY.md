# V29 Deployment
1. Keep using the existing KEYDHAN_DB KV namespace.
2. Bind it to Worker as KEYDHAN_DB.
3. Deploy worker.js and keep the custom API domain admin-api.keydhan.com.
4. Test /api/health and /api/properties.
5. Publish admin/ and public/ through GitHub Pages.
6. Protect keydhan.com/admin/* with Cloudflare Access.
7. For image storage, configure R2 separately; do not put Cloudflare secrets in GitHub Pages files.
