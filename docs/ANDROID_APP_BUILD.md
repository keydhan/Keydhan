# KeyDhan Android App — Build Plan

## Current implementation

This branch adds the first PWA foundation for the KeyDhan Android app:

- Web app manifest with standalone display, portrait orientation, app identity, and navy/gold theme.
- Branded scalable SVG app icon.
- Root-scoped service worker with conservative caching.
- Branded offline fallback page.
- Homepage manifest link, mobile app metadata, and service-worker registration.

## Safety boundaries

- This work is isolated to `feature/keydhan-android-app`.
- Do not merge or deploy to production as part of this phase.
- The service worker bypasses non-GET requests and sensitive `/admin`, `/api/`, `/worker`, and `/cdn-cgi/` paths.
- Do not cache admin pages, API responses, lead submissions, payment operations, or customer documents.

## Remaining Android packaging tasks

1. Verify PWA installability and service-worker behavior on the deployed HTTPS domain.
2. Produce and add dedicated 192x192 and 512x512 PNG launcher icons (including a maskable icon) for broad Android/TWA compatibility.
3. Confirm the final Android application ID (recommended: `com.keydhan.app`, subject to package-name availability).
4. Build the Trusted Web Activity wrapper with Bubblewrap against `https://keydhan.com/`.
5. Generate a signing key and record its SHA-256 certificate fingerprint securely.
6. Publish `/.well-known/assetlinks.json` with the exact package name and signing fingerprint. Never guess the fingerprint.
7. Build a signed APK for device testing and an AAB for Play Console.
8. Test navigation/back behavior, external links (WhatsApp/phone), file downloads, local file processing, offline fallback, and all customer enquiry flows.
9. Submit to Google Play only after the user approves the tested release.

## Validation still required

The repository connector can verify committed source files, but it does not run the site's browser tests or Android Gradle/Bubblewrap build. Do not describe an APK as built until an actual signed artifact has been generated and installed successfully.
