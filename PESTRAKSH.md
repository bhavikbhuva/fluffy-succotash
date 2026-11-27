# PestRaksh: the customer app

This is the vendor's SnapBuy Customer app 1.6.0 (Flutter), turned into the PestRaksh customer app. The first
commit, `ee3a94b`, is the vendor app exactly as received; every PestRaksh change is a commit after it. The
README is the vendor's.

- **Plan, owner decisions and the full story:** `docs/APP_PLAN.md` in the backend repo
  (`bhuvabhavik/services-backend`). The roadmap is `docs/ROADMAP.md` there.
- **Sister app:** the technician app, private repo `bhavikbhuva/fluffy-fishstick`, set up the same way.

## Status (26 Nov 2026): basic reskin (Phase 0)

- **Done:**
  - name "PestRaksh", app ID `com.pestraksh.app`, our server and website;
  - the logo, orange, a light splash, no Facebook tracking;
  - its own signing key, Firebase, the cloud build, and the booking wording built in.
- **First APK:** 26 Nov 2026, built from `c14e219` (Flutter 3.50.1), 46 MB, signed with this repo's key
  (SHA-256 checked). The first cloud build had failed on an old payment plugin (`flutter_paystack`); fixed in
  `b191c2e`.
- **Phase 1 built, 26 Nov 2026: booking works in the code.** Pushed at 18:34 (`a25c97a`), but GitHub
  started no build for it: the commit message contained the text "[skip ci]" inside a sentence ("Not marked
  [skip ci]"), and GitHub skips the build whenever that text appears anywhere in the newest commit's message.
  An empty commit (`9d9dc0c`) started it: the Phase 1 APK was built on 27 Nov 2026 and is on the owner's
  Desktop as `PestRaksh-phase1.apk`. The owner's test is still to do. The phase brought:
  - India time (`lib/utils/server_time.dart`), so times are no longer 5½ hours late;
  - the texts refresh at each start;
  - checkout's "Service Schedule & Time Slot": the date strip and arrival windows, sent as `booking_date` and
    `booking_slot_id`, which the backend requires;
  - the Pick Up switch hidden.

  The APK of 26 Nov (`c14e219`) can't book yet.
- **Phase 2, part 2A built, 27 Nov 2026 (not pushed):** "From ₹…" on service cards and list rows (the
  cheapest bookable package, `lib/features/products/utils/package_price.dart`); "✓ Added" instead of the
  − 1 + stepper (`commons/widgets/cart_button.dart`); ADD refuses a second package of the same service.
  Pushed 27 Nov (`3f5b4fa`).
- **Phase 2, part 2B built, 27 Nov 2026 (not pushed):** the service page's title is the service, with
  "Package: …" under it; a warranty tile when the package has one (`utils/warranty_label.dart`); "Service not
  found" for a deleted service (`ProductDetailNotFound`). The build workflow's publishing steps now run
  independently and are each reported in `ci-status`. Pushed 27 Nov (`9f861dc`).
- **Phase 2, part 2C built, 27 Nov 2026 (not pushed):** each cart row names the booked package; Remove
  (with a confirm) instead of the − 1 + stepper; an applied promo is checked again when the subtotal
  changes. Pushed 27 Nov (`399ded0`): its APK, with Phase 1 and all of Phase 2, is on the owner's Desktop
  as `PestRaksh-phase2.apk`. Details in the backend's `docs/APP_PLAN.md`.
- **Phase 3, parts 3A and 3B built, 27 Nov 2026 (not pushed):** My Bookings without the Quick / Shop and date
  filter; cards with the service over the package, the appointment and the technician; Book Again in Quick
  mode; follow-up visits at the top of Upcoming (`booking_visits/upcoming`).
- **Phase 3, part 3C built, 27 Nov 2026 (not pushed):** the booking page titles each line by its service with
  the package under it, shows an Appointment and Technician card, and the status without "Booking" before it.
  Phase 3 pushed 27 Nov (`7eeb4d0`); its APK, with Phases 1–3, is on the owner's Desktop as
  `PestRaksh-phase3.apk`.
- **Owner, in the admin:** Zones → Bangalore → **Quick** only, which hides the Quick / Shop switch in the app.
- **Texts as on the website** (26 Nov 2026): Refund Policy, Privacy Policy, Book Again, Continue with Google,
  and the My Bookings tabs Upcoming / Past. They are in `assets/languages/en.json` here and in the backend's
  file.
- **What's next:** the rest of the work is split into Phases 1–9 in the plan (`docs/APP_PLAN.md` in the
  backend, "The work, phase by phase"). Each phase ends with one APK and the owner's phone test.

## Everything needed is in this repo

The repo is private for good (owner, 25 Nov 2026), so nothing has to be kept on a computer. A fresh clone
builds as is.

| File | What it is |
|---|---|
| `env/prod.json`, `lib/core/configs/app_config.dart` | Name "PestRaksh", app ID `com.pestraksh.app`, server `https://admin.pestraksh.com/customer/`, website `https://pestraksh.com`, deep links `pestraksh://`; the active environment is `prod` |
| `android/app/upload-keystore.p12`, `android/key.properties` | This app's own upload signing key (PKCS12, alias `upload`, valid until 2056) and its password. SHA-1 `88:87:DB:BD:0D:DF:3E:05:1B:E2:17:5F:FA:5A:FA:E5:15:92:2B:63`, SHA-256 `2B:C4:1E:6B:E8:E8:BA:01:BC:13:97:60:E7:38:C6:90:21:77:6B:76:7B:3D:02:A9:FA:C8:B2:F0:94:5C:58:F4` |
| `android/app/google-services.json`, `lib/firebase_options.dart` | Firebase project `pestraksh`, the website's, so logins pass the backend's check. The Firebase Android app `com.pestraksh.app` has both fingerprints above (added by the owner, 26 Nov). Android only so far |
| `.github/workflows/android-build.yml` | The cloud build (below) |
| `pubspec.lock` | Package versions from the first good build (Flutter 3.50.1), including the commit of the vendor's `flutter_paystack` fork |
| `assets/logo/*`, `assets/images/png/pestraksh_logo.png` | Logo masters for the icons and the splash |
| `tool/pestraksh_make_icons.py` | Rebuilds every icon from the logo (Python 3 with Pillow) |

**Keep a second copy of the signing key** (`upload-keystore.p12` plus `key.properties`) outside GitHub, for
example in Google Drive. Updates to a Play Store app must be signed with it.

If the signing key ever changes, add the new SHA-1 and SHA-256 in Firebase (Project settings → Your apps →
`com.pestraksh.app` → Add fingerprint). Without them, Google and phone login fail.

## Getting an APK (no Flutter needed)

1. Push to `main`. GitHub Actions builds a signed release APK in about 20 minutes.
2. Put `[skip ci]` in the message of a commit that changes only notes, so it doesn't start a build.
   GitHub finds that text anywhere in the newest commit's message, even inside a sentence, so never write
   it in a commit that should build (26 Nov 2026: "Not marked [skip ci]" skipped the Phase 1 build).
3. Get the APK:
   - **With git:** `git fetch origin apk && git show FETCH_HEAD:app-arm64-v8a-release.apk > PestRaksh.apk`.
     Use the arm64 file for any modern phone.
   - **On GitHub:** the "test-build" release.
4. The result is on the `ci-status` branch:
   - `git fetch origin ci-status && git show FETCH_HEAD:status.md`;
   - also `what-went-wrong.log`, `errors.log` and `build-tail.log`.

To build on a computer instead: Flutter stable, Java 17 and the Android SDK (compile SDK 36), then
`flutter pub get && flutter build apk --release --split-per-abi`.

**Checking code without a build:** Flutter alone is enough for `flutter analyze` and `flutter test`; no Java or
Android SDK is needed. On 26 Nov 2026 Flutter 3.50.1 (the cloud build's version) was downloaded into a temporary
folder for this, from `storage.googleapis.com/flutter_infra_release`.
- Our tests are in `test/pestraksh/`.
- `flutter analyze` on the vendor code gives about 358 notices, all of them Flutter deprecation infos; no
  errors or warnings.
- Vendor tests:
  - `test/commons/cubit/base_pagination_cubit_test.dart` has one test that fails even on the untouched vendor
    code;
  - the full `flutter test` run does not finish (some vendor tests hang), so run folders with
    `--timeout 60s`.

## Settings that live on the server, not in the app

These change without a new app build:
- **Texts:** `resources/lang/apps/customer/en.json` in the backend. Copy it into `assets/languages/en.json`
  here before each release; that copy is the offline fallback.
  - Since `8f11e66` the app shows its cached copy at once and fetches the server's at each start.
  - Builds before that keep the first copy they downloaded, so a change reaches them only after a fresh install
    or cleared app data.
- **Colours:** Admin → Settings → App Settings (customer light and dark colour, now orange).
- **Home page and content:** the Home Builder, banners, services, prices and policies.
- **Map:** `map_provider` is `osm`, OpenStreetMap, so no Google Maps key is needed.
- **Times:** the backend sends India time; the vendor app reads plain times as UTC (see "Times" in the plan).

## PestRaksh commits

| Commit | What |
|---|---|
| `ee3a94b` | Vendor SnapBuy Customer app 1.6.0, as received (without the zip's `__MACOSX` and `.DS_Store`) |
| `da19e43` | Config, signing and Firebase files kept in git |
| `bdd8e1b` | Our server, name "PestRaksh", app ID `com.pestraksh.app`, deep links, version 1.0.0 |
| `b1d7840` | PestRaksh logo: app icon, notification icon, splash (identical to the technician app's) |
| `c31401a` | No Facebook tracking |
| `d365d44` | Light splash, orange as the built-in colour |
| `88b324c` | This app's signing key |
| `75d98a7` | Android Gradle Plugin 9.1.1 (needed by Flutter stable) |
| `6b73e55` | Cloud build (the technician app's workflow) |
| `51ced4f` | Booking wording built in (230 texts from the backend's file) |
| `5a21e7a` | Firebase project `pestraksh` for Android |
| `b191c2e` | Old plugins raised to compile SDK 36 (`flutter_paystack` failed the first build) |
| `c14e219` | The build report keeps Gradle's "What went wrong" |
| `1c0b2b3` | This file and `tool/pestraksh_make_icons.py` |
| `f1d38c2` | `CLAUDE.md`: the owner's working rules |
| `441c87d` | `pubspec.lock` from the first good build |
| `7ad5295` | Texts as on the website: Refund Policy, Privacy Policy, Book Again, Continue with Google, Upcoming / Past |
| `5fb719f` | India time: plain API times are India time, not UTC (Phase 1) |
| `8f11e66` | Texts refresh at each start (Phase 1) |
| `88d7ce3` | Booking date and arrival window at checkout; Pick Up switch only when offered; tests (Phase 1) |
| `a25c97a` | This file: Phase 1 |
| next commits | Phase 2, part 2A: service cards; then this file |
