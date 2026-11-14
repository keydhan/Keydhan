# KeyDhan Android – Phase 2

## Goal
Upgrade the working v0.1 test wrapper with a branded native launch experience and a verified Android interaction test pass. All work remains on `feature/keydhan-android-app`; do not merge or deploy the website as part of this phase.

## Included preparation
- Capacitor App, Browser, Splash Screen and Status Bar plugins added.
- Native launch screen configured for KeyDhan navy (#0B1530), with a short 1.8 second launch window and no spinner.
- Status bar configured with a navy background and light icons/text.
- Android app identity remains `com.keydhan.app`.

## Implementation and QA sequence
1. Generate branded launcher and splash artwork at Android densities (including adaptive/maskable icon treatment); verify crop and safe area on small and large screens.
2. Install and verify splash/status-bar plugin resources on a physical Android device. Confirm splash hides after the first page is visibly ready, not just after a fixed delay.
3. Validate Android back behavior:
   - Back navigates WebView history when available.
   - Back on the home page exits the app rather than leaving a blank page.
   - No accidental double-exit or stuck splash state.
4. Validate external intents:
   - `tel:` opens the phone dialer.
   - `https://wa.me/` and `whatsapp://` open WhatsApp when installed; otherwise show a graceful fallback.
   - External links open safely without breaking in-app navigation.
5. Validate document downloads:
   - PDF and image downloads complete and can be opened from Android downloads.
   - Permission prompts are correct for supported Android versions.
   - No private admin/API response is cached or exposed.
6. Run a device test pass on at least one current Android version and one older supported version; record OS/device, result, and reproducible defects.
7. Run cold start, warm start, offline, slow network, orientation, low-memory/reopen and repeated navigation checks. Capture crashes and logcat traces before any release decision.

## Release gates
- Build workflow green and APK artifact present.
- Splash, back, WhatsApp, dialer and document-download tests pass on a physical device.
- No critical crash, blank screen, broken navigation or admin/API caching issue.
- Keep this as a debug/testing APK. A Play Store release needs a separately managed signing key, Digital Asset Links / TWA decision, privacy/data-safety review and signed AAB.

## Current limitations
The Capacitor wrapper loads `https://keydhan.com`. Adding native plugins and config does not by itself prove that remote website links invoke native plugins. Back handling, external intent routing and downloads must be validated end-to-end; if the live site's navigation needs JavaScript integration, do that only through a separately reviewed Android bridge or an approved website change. No production site change is authorized by this phase.
