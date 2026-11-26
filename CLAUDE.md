# PestRaksh customer app ("PestRaksh", `com.pestraksh.app`)

Flutter (the Dart package is `customer`). Start with `PESTRAKSH.md`: status, the files that matter, and how to
get an APK. The plan and the owner's decisions are in `../services-backend/docs/APP_PLAN.md`.

## This repo

- **Secret files are committed on purpose.** The owner decided this repo stays private for good (25 Nov 2026).
  Don't remove these files or flag them as a security issue:
  - `env/prod.json`;
  - `android/key.properties` and `android/app/upload-keystore.p12`;
  - `android/app/google-services.json` and `lib/firebase_options.dart`.
- **No Flutter on the Mac:**
  - push `main` and GitHub Actions builds the APK (on the `apk` branch, with the result on `ci-status`);
  - put `[skip ci]` in commits that change only notes;
  - with no compiler at hand, re-read every Dart and Gradle change before pushing.
- The first commit, `ee3a94b`, is the vendor app as received. Mark changes `// PestRaksh:`.
- **Backend first.** Texts (`resources/lang/apps/customer/en.json`), colours, content and booking rules come
  from the backend: change them there, not in the app. Copy the backend's texts into
  `assets/languages/en.json` before each release; that copy is the offline fallback.
- **Firebase** is the website's project, `pestraksh`. The backend accepts phone and Google logins only from
  that project. If the signing key ever changes, add its SHA-1 and SHA-256 to the Firebase app, or login
  breaks.
- **The app can't place a booking yet.** The backend requires a booking date and time slot, and the vendor app
  has no slot picker (Phase 1 of the plan).
- **Times:** the API sends India time, and the vendor code reads plain times as UTC.

## Working rules for all four PestRaksh repos

These are the owner's standing rules. The same block is in each repo's `CLAUDE.md`, so change all four
together. Written 26 Nov 2026 from Claude's notes on the old office Mac. When the owner gives a new standing
rule, add it here in all four repos, not only to Claude's memory, which stays on one computer.

### The four repos

Clone them side by side in one folder, under these folder names; the docs refer to them by name. For
example: `git clone https://github.com/bhavikbhuva/fluffy-succotash.git services-app`.

| Folder | GitHub (private) | What |
|---|---|---|
| `services-backend` | `bhuvabhavik/services-backend` | Laravel admin panel and API, `admin.pestraksh.com` |
| `services-frontend` | `bhuvabhavik/services-frontend` | Next.js website, `pestraksh.com` |
| `services-app` | `bhavikbhuva/fluffy-succotash` | Flutter customer app "PestRaksh" (`com.pestraksh.app`) |
| `services-delivery` | `bhavikbhuva/fluffy-fishstick` | Flutter technician app "PR Technician" (`com.pestraksh.partner`) |

PestRaksh is pest-control service booking for Bengaluru, built on the vendor's SnapBuy (WRTeam) e-commerce
system and turned into service booking (booking date and time slot, visits, technicians).

### Notes

- **All notes live in the backend repo,** in `services-backend/docs/`:
  - `ROADMAP.md`: open work, owner decisions, checks after a deploy, and a dated "Done" log;
  - `SNAPBUY_1.6.0_PORT.md`: what was taken from the vendor's 1.6.0, what wasn't, and our deliberate
    differences;
  - `APP_PLAN.md` (customer app), `TECHNICIAN_APP_PLAN.md`, `KANNADA_REVIEW.md`.
- **Update `ROADMAP.md` and `SNAPBUY_1.6.0_PORT.md` with every change, in any repo, as part of the same
  work.** Tick or add items, add a dated "Done" entry, and update "Last updated". The owner asked for this
  explicitly.
- Other Claude sessions may edit `ROADMAP.md` at the same time: commit only your own changes to it, never
  someone else's half-written lines.

### Pushing and deploying

- **Push only when the owner asks.**
- Pushing `main` is live: the backend and the website deploy themselves, and each app builds an APK on
  GitHub.
- When a change touches both the website and the backend, push the **website first**, wait until it is live,
  then the backend.
- Backend: the server does not build the admin's assets, so `public/build` is committed. Commit the source and
  the build as two separate commits; the owner dislikes huge mixed diffs.

### Content and claims

- **Hommlie** (`hommlie.com`), the reference competitor:
  - copy their structure (pest list, package types, the "What pest problem are you facing?" grid) and their
    prices (owner, 23 Nov 2026);
  - never their text or photos.
- **Confirmed facts** (owner, 25 Nov 2026):
  - open every day, 9 am to 7 pm;
  - +91 72019 49464 takes calls and WhatsApp;
  - technicians are trained by PestRaksh: say "trained", not "certified";
  - the founders are Bhavik Bhuva and Bhavik Hirani, but don't show their names on the site for now.
- **Not confirmed, so never claim:** founding year, years of experience, PCO licence, CIB&RC registration,
  chemical brands, customer counts or ratings, re-treatment warranties, "WHO-approved".

### Privacy

The Claude account is a shared office account, so **never publish claude.ai artifacts**. Make mock-ups and
previews as local files (a PNG or HTML on the Desktop) and give the path.

### Vendor code

- Each repo's first commit is the untouched vendor code, kept for diffs when the vendor releases an update.
- Mark our changes with `PestRaksh:` comments, and code ported from the vendor's 1.6.0 with `SnapBuy 1.6.0`.
- Never unzip a vendor package over a server: the zips contain a `.env` and compiled files that would
  overwrite ours.
