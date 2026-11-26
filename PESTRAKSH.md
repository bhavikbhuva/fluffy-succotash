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
- **The app can't place a booking yet.** The backend requires a booking date and time slot, and the vendor app
  has no slot picker. That is the first job of Phase 1 in the plan. Until then: browse, log in, see bookings.
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
3. Get the APK:
   - **With git:** `git fetch origin apk && git show FETCH_HEAD:app-arm64-v8a-release.apk > PestRaksh.apk`.
     Use the arm64 file for any modern phone.
   - **On GitHub:** the "test-build" release.
4. The result is on the `ci-status` branch:
   - `git fetch origin ci-status && git show FETCH_HEAD:status.md`;
   - also `what-went-wrong.log`, `errors.log` and `build-tail.log`.

To build on a computer instead: Flutter stable, Java 17 and the Android SDK (compile SDK 36), then
`flutter pub get && flutter build apk --release --split-per-abi`.

## Settings that live on the server, not in the app

These change without a new app build:
- **Texts:** `resources/lang/apps/customer/en.json` in the backend. Copy it into `assets/languages/en.json`
  here before each release; that copy is the offline fallback.
  - The app keeps the first copy it downloads (`lib/core/localization/cubit/localization_cubit.dart`). A server
    change reaches a phone only after a fresh install or cleared app data.
  - This lasts until the plan's Phase 1 item "Texts refresh at each start".
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
| next commit | Texts as on the website: Refund Policy, Privacy Policy, Book Again, Continue with Google, Upcoming / Past |
