# Cashfree Payments for KeyDhan Business Services

## Status

Preparation branch only. Cashfree merchant KYC is currently under review. The public Business Services catalogue and fee presentation have been prepared, but payment checkout, live credentials, and production deployment remain disabled.

## Scope

Add a centralised payment flow for KeyDhan's paid business-assistance services:

- GST registration assistance and related GST services
- PAN application / correction assistance
- MSME / Udyam registration assistance
- Trademark application assistance
- Other admin-configured business services

KeyDhan must describe these as assistance / professional services where applicable. It must not imply that KeyDhan is a government portal, that government approval is guaranteed, or that government fees are KeyDhan's own fees.

## Confirmed KeyDhan professional service fees

The following are KeyDhan's professional/service fees in INR. Government, statutory, or authorised-agency charges are separate, are not included in these amounts, and must be shown as a distinct line item only after the actual applicable amount is confirmed:

| Service | KeyDhan service fee | Government fee |
|---|---:|---|
| GST registration assistance | ₹1,000 | Extra, as applicable |
| PAN application / correction assistance | ₹500 | Extra, as applicable |
| MSME / Udyam registration assistance | ₹500 | Extra, as applicable |
| Trademark application assistance | ₹2,000 | Extra, as applicable |
| GST return filing assistance | To be confirmed | Separate, if applicable |

These are professional service fees, not government fees. The service catalogue remains inactive until launch approval. No tax/GST treatment on KeyDhan's service fee has been assumed; confirm the applicable tax treatment before enabling checkout.

## Completed before Cashfree activation

- Public Business Services catalogue now presents GST Registration, PAN Application / Correction, MSME / Udyam Registration, and Trademark Assistance.
- Displays KeyDhan professional fees: ₹1,000, ₹500, ₹500, and ₹2,000 respectively.
- Clearly states government / statutory / authorised-agency charges are extra and will be confirmed separately.
- Public page states KeyDhan is not a government portal and is not collecting GST while unregistered.
- Existing WhatsApp enquiry remains the action path; no payment button or gateway claim is shown.
- Confirmed service fee amounts are stored in the isolated D1 sandbox catalogue; all services remain inactive pending launch approval.

## Existing architecture observed

- Public Business Services page: `business-services.html`
- Public Business Services script: `business-services.js`
- Admin API / Cloudflare Worker: `worker.js`
- Current Worker data store: Cloudflare KV binding `KEYDHAN_DB`
- Admin navigation and shared API helper: `admin/index.html`, `admin/common.js`
- Existing Business Services page currently routes enquiries to WhatsApp.
- The current Worker does not expose Cashfree payment endpoints and the repository's current Worker configuration has KV, not a D1 binding.

## Recommended architecture

1. Customer selects a service and submits the minimum contact / application details required to request assistance.
2. The browser requests an order from the KeyDhan Worker using a service identifier, never a trusted amount.
3. The Worker loads the active service and price from server-controlled configuration, creates a unique internal order ID, and creates a Cashfree order server-side.
4. The browser receives only the Cashfree payment session ID and opens Cashfree Hosted Checkout using the official Cashfree JS SDK.
5. Cashfree sends an asynchronous webhook to the Worker. The Worker verifies the signature against the exact raw request body before accepting the event.
6. The Worker retrieves / validates the authoritative order payment state with Cashfree where required. A browser redirect or client callback alone must never mark an order paid.
7. After verified payment, the Worker records the payment and service request, then exposes the record to the authenticated Admin Panel.
8. Admin can review payment state and update service fulfilment state independently.

## Data storage decision

Payment and service-request records require reliable auditability and concurrent updates. Do not use a single KV JSON array as the payment ledger: KV is eventually consistent and does not provide transactional writes.

Before implementing persistent payment endpoints, provision a Cloudflare D1 database and bind it to the API Worker (for example, `KEYDHAN_PAYMENTS_DB`). Create migrations for:

- `business_services`: service key, display name, active flag, fee amount in paise, tax treatment, description, updated timestamp.
- `payment_orders`: internal order ID, Cashfree order ID, service key, customer reference, amount in paise, currency, payment status, gateway environment, timestamps.
- `payment_events`: provider event / payment ID, order ID, event type, signature-verification result, received timestamp, processing result; enforce uniqueness to make webhook processing idempotent.
- `business_service_requests`: request ID, order ID, service key, customer contact details, fulfilment status, timestamps.

Store money as integer paise. Calculate amounts on the server from the active service catalogue. Keep government charges separate from KeyDhan professional fees and only include them when their actual amount and collection authority are established.

Do not store full card data, UPI PINs, passwords, or unnecessary Aadhaar / PAN document images in payment records. Collect sensitive identity documents only through a separately reviewed, access-controlled workflow when genuinely required.

## Security requirements

- Keep Cashfree App ID and Secret Key only in Cloudflare Worker secrets. Never place secrets in HTML, JavaScript, GitHub, KV content, logs, or Admin browser storage.
- Keep Sandbox and Production credentials and environments strictly separate.
- Validate service key, customer input, currency, and server-calculated amount before creating an order.
- Use cryptographically unpredictable unique order IDs and idempotency safeguards.
- Verify Cashfree webhook signatures using the exact raw request body and Cashfree's documented signature algorithm / headers.
- Make webhook processing idempotent; duplicate notifications must not create duplicate service requests or receipts.
- Confirm payment status server-side with Cashfree before fulfilment.
- Require existing Admin API authentication for payment-management endpoints; do not expose customer payment records publicly.
- Apply rate limits, input limits, CORS restrictions, and safe error messages to public payment endpoints.
- Never mark an order paid from a return URL query string or browser callback alone.

## Admin Panel requirements

Add a Payment Management navigation item and authenticated screen with:

- Total successful collections, successful count, pending count, and refunds.
- Search by customer, mobile, internal order ID, and Cashfree order / payment reference.
- Filters for service category, payment status, date range, and gateway environment.
- Payment detail view with amount breakdown, timestamps, and provider references.
- Separate service fulfilment status: New, In Progress, Completed, On Hold, Cancelled.
- Refund initiation only after gateway API support, permission checks, and confirmation flow are implemented.
- Exportable reports that do not expose unnecessary identity documents.

## Customer experience requirements

- Mobile-first service selection and checkout.
- Show service description, KeyDhan professional fee, applicable tax, and any government fee as separate line items.
- Show the total payable before checkout.
- Display clear Pending, Paid, Failed, and Cancelled outcomes.
- Provide a receipt / acknowledgement with a unique KeyDhan reference and payment reference.
- Explain service scope, estimated processing time, cancellation / refund rules, and that final government approval and timelines are controlled by the relevant authority.
- Preserve the existing WhatsApp enquiry route as a fallback until payment flow is tested and approved.

## Phased delivery and release gates

### Phase 0 — current preparation
- Record architecture, scope, data model, security and compliance requirements.
- Keep all work on a feature branch and draft PR.
- Do not deploy or merge to production.

### Phase 1 — prerequisites
- Complete Cashfree merchant KYC and obtain Sandbox access / credentials.
- Confirm legal trade name / proprietor name, bank settlement details, and final fee / tax wording with the accountant.
- Confirm the legal merchant name, approved business category, settlement account, and service descriptions.
- Publish and review Privacy Policy, Terms, Refund & Cancellation Policy, Contact details, service fees, and delivery timelines.
- Provision D1 and apply migrations in a non-production environment.

### Phase 2 — sandbox implementation
- Implement server-side order creation, hosted checkout, payment verification, and signed webhook processing.
- Add authenticated Admin payment records and service fulfilment management.
- Test success, failure, cancellation, pending / late authorisation, duplicate webhook, invalid signature, amount tampering, replay, and interrupted browser-return scenarios.
- Verify that no service is marked paid or fulfilled without server-side confirmation.

### Phase 3 — production readiness
- Obtain Cashfree production activation and production credentials.
- Configure secrets and webhook URL in the production Worker only after explicit approval.
- Run production smoke tests with a controlled low-value transaction.
- Deploy only after review and explicit release approval.

## Cashfree integration reference

Use Cashfree's current official Hosted Checkout documentation and current API version at implementation time:
- https://www.cashfree.com/devstudio/preview/pg/web/checkout
- https://www.cashfree.com/devstudio/preview/pg/tools/webhookVerification

Do not copy credentials or test secrets from documentation examples into the repository.
