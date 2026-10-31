# KeyDhan Growth Roadmap — 2026–27

Status: Phase 1 audit and implementation planning. This document does not change production behaviour.

## Goals
Build sustainable organic discovery and convert relevant visitors into qualified enquiries across:
1. Real estate
2. Loans and financial solutions
3. Knowledge Centre
4. Free browser tools

No ranking, traffic, approval, or lead-volume guarantees are implied.

## Repository audit — 31 October 2026

### Existing foundations confirmed in the repository
- Public pages include the homepage, properties, calculator, business services, about, contact, legal pages, and a 47-tool directory.
- `sitemap.xml` currently lists 55 URLs, including the core pages and tools.
- `robots.txt` allows public crawling and disallows `/admin/`.
- Homepage has Organization, WebSite, and WebPage JSON-LD entities.
- Properties page has WebPage JSON-LD and loads property records from the public API.
- `site-header.js` is already used as a shared navigation source on the main site.
- Cloudflare Worker API stores properties, leads, offers, settings, and page content in KV.
- Admin has existing Properties, Leads, Page Content, and Analytics screens.
- Existing Admin Analytics reports CMS counts only; it is not yet connected to Search Console or GA4.

### Important implementation constraints
- Property data currently has title, location, price, image, description, type, bedrooms, bathrooms, area, map URL, status, featured, and timestamps. It does not yet contain a verified SEO slug, complete photo gallery, amenities, author/editorial notes, or legal/availability verification fields.
- The current public properties page fetches a list and renders cards client-side. Individual indexable property pages need a server-rendered or statically generated route strategy; a client-only query-string page is not sufficient for the SEO objective.
- The Worker API is deployed separately from the GitHub Pages public site. Changes to `worker.js` in this repository do not, by themselves, prove that the Cloudflare Worker has been deployed.
- GA4/Search Console integration requires an authorized Google connection or securely configured API credentials. Never store credentials in public repository files or browser JavaScript.
- No new property, price, interest rate, lender offer, testimonial, author credential, or regulatory registration detail should be fabricated.
- The two sample records in `data/properties.json` must not be treated as current live inventory without verification; the live public API/KV is the source used by the properties page.

## Phased delivery plan

### Phase 1 — Measurement and technical baseline
- Confirm the production sitemap and robots response.
- Review Search Console coverage, queries, clicks, impressions, CTR, and landing pages.
- Review GA4 landing pages, engagement, and enquiry events.
- Define baseline metrics for a 28-day comparison window.
- Audit canonical URLs, metadata, structured data, mobile layout, broken links, and page performance.
- Add no Google credentials to source control.

**Exit criteria:** verified baseline report, list of actionable issues, and documented analytics integration method.

### Phase 2 — Property detail architecture
- Extend property records with a unique stable slug and optional gallery, amenities, property type, verified status, and last-verified date.
- Add admin validation and slug uniqueness checks.
- Design crawlable individual property URLs using static generation or an edge-rendered route.
- Generate canonical, unique title/description, breadcrumb data, and only schema supported by the actual property facts.
- Update sitemap from published, verified records only.
- Preserve existing property listing, pagination, and enquiry flows.

**Exit criteria:** at least one owner/admin-verified listing passes mobile, link, canonical, structured-data, and enquiry smoke tests before rollout.

### Phase 3 — Knowledge Centre
- Create a crawlable category index and article detail route.
- Add article CMS fields: title, slug, summary, body, category, language, author/reviewer, sources, published/updated dates, status, and SEO metadata.
- Support draft/preview/publish workflow and slug uniqueness.
- Publish only reviewed, useful original content. Finance content must cite current authoritative sources and explain assumptions, fees, eligibility variability, and risks.
- Add contextual links to relevant calculators, services, and property pages.

**Exit criteria:** article publishing, preview, canonical, sitemap, mobile, and editorial review workflows tested.

### Phase 4 — Financial Tools Hub
- Audit existing tools before adding duplicates.
- Prioritize home-loan eligibility, home affordability, balance transfer, stamp duty, prepayment, and business-loan EMI tools.
- Document assumptions and calculation limitations in each tool.
- Add relevant internal links and non-intrusive enquiry calls to action.

**Exit criteria:** calculation test cases independently checked and every tool has transparent assumptions.

### Phase 5 — Local SEO
- Start with locations where KeyDhan can provide genuine service or verified inventory.
- Create distinct location pages with useful local information, actual service coverage, relevant inventory, and contact details.
- Avoid city-name substitution and doorway pages.
- Do not publish unsupported local office or RERA claims.

**Exit criteria:** each page has unique evidence-backed content and a real user purpose.

### Phase 6 — Loan comparison centre
- Display lender, product, rate range, fees, eligibility, source URL, and last-verified date only when verified.
- Clearly state that rates and approval depend on lender policy and applicant profile.
- Add an expiry/review process so stale offers are unpublished.

**Exit criteria:** every displayed offer has a current source and verification date.

### Phase 7 — Video and property showcase
- Add optional video URL, caption, transcript/summary, and thumbnail to verified property/content records.
- Embed videos accessibly and provide useful text on the page.
- Do not create thin pages that contain only an embedded video.

### Phase 8 — Lead conversion and Admin reporting
- Track source page, campaign parameters, enquiry type, and consent where appropriate.
- Preserve duplicate-submit protection and existing email/lead workflows.
- Connect GA4/Search Console through secure authorization.
- Show organic clicks, impressions, CTR, landing pages, top queries, and enquiry conversion in Admin only after data access is configured.
- Separate analytics failures from lead/API failures; never expose secrets to the browser.

## Proposed KPI scorecard
Establish a 28-day baseline first, then compare:
- Organic clicks and impressions
- Search CTR and average position
- Indexed eligible URLs
- Organic landing-page engagement
- Enquiry submissions by landing page and enquiry type
- Qualified leads and enquiry-to-qualified-lead rate

## Rollout and safety rules
- Implement one phase at a time on a feature branch.
- Review the diff and run available tests before merge.
- Deploy the public Pages site and Cloudflare Worker separately where applicable.
- Verify deployment run and production smoke tests before calling anything live.
- Keep existing public pages, calculators, tools, admin access, and lead capture working.
- Never commit API keys, OAuth tokens, personal customer data, or private analytics exports.
