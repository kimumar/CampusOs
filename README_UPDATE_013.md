# CampusOS Update 013 — Consolidated source, security and lean scaling revision

**This is source code, NOT a verified APK or production release.** The complete current Flutter `mobile/` and Django `backend/` trees are included. It supersedes the uninstalled Updates 011 and 012. It is designed to merge into the existing project; **never wipe project or device storage**.

## Included and amended

- Update 012 feature baseline retained: trial (3 days), monthly/quarterly price settings (₦700/₦2,000 defaults), complementary unlimited or time-limited access, 24-hour offline entitlement, restricted Home/Profile plus unsaved GPA calculator, local Android reminders, university referral codes/links, private partner dashboards, per-partner ₦0 or custom rate, owner-level Django Admin controls, audit-aware payment records, and preservation of academic records.
- Fixed the seven-calendar-day deadline window boundary (`today + 7 days` is included).
- Campus Pulse now counts all *eligible trial/paid/complimentary students* automatically regardless of the legacy `pulse_opt_in` field, including subscribed accounts that record zero progress. The Profile screen now presents an informational privacy explanation, not an opt-in toggle. No names or student counts are returned by the aggregation response. Privacy notice must be reviewed before release.
- Authenticated Django academic-record API now returns HTTP 403 for expired users, preventing simple direct-API bypass of the Home/Profile restriction. Their saved server data is **not deleted**.
- Periodic full sync attempt interval increased from 5 to 30 minutes to reduce server and phone overhead. Edits still request immediate debounced sync (2 seconds); manual and resume sync remain available.
- Preserved current premium purple UI instead of applying generated mockup images. Native Flutter theming avoids rendering/image asset overhead.
- Added backend regression cases for Pulse eligibility, expired API access and absent data; existing tests retained.

## Security and business controls

- Server checks entitlement; app checks the 24-hour last-online-verification window. Modified devices/clocks and reverse-engineered APKs can still attack purely local entitlement checks. Consider signed monotonic time attestation for higher assurance later.
- Recorded bank settlements in Django Admin are **manually trusted**. There is **no payment gateway reconciliation or webhook**. Never treat a staff-clicked 'verify' action as independent bank verification.
- Commission rewards are first verified-conversion only and immutable once recorded; partner portal queries are scoped by login ownership.
- Production authentication/email, HTTPS, app-store billing policies, security audit, and data protection consent/notices need deployment configuration/review. Cloud notifications and iOS background scheduling are **not delivered** in this source.
- Campus Pulse automatically aggregates user progress: disclose this clearly in privacy notice/terms, because it is no longer optional. Small populations can create inferences despite no public identities; consider publishing only coarse ranges for small cohorts if this becomes a material risk.
- App users who lack access receive Home/Profile only. Local existing records are never erased due to subscription expiry.

## Installation

1. Back up your current `Desktop\CampusOS` project, database (`.sqlite3` or server PostgreSQL backup), user secrets, and any important device data. Stop running Django/Flutter before applying.
2. Save this ZIP on Desktop and run the included `INSTALL_UPDATE_013.ps1` from PowerShell. The installer checks file presence and manifest integrity, creates a separate backup, merges source without deleting existing files, and runs available code checks. It does **not** run migrations or deploy/build automatically. On failure, restore from the created backup as indicated.
3. From `backend` with activated venv: `python manage.py makemigrations --check --dry-run`, `python manage.py migrate --plan`, `python manage.py check`, then `python manage.py test`. Review proposed migrations and back up DB before applying `python manage.py migrate`.
4. From `mobile`: `flutter pub get`, `flutter analyze`, `flutter test`. Build with real same-network IP for development or a real HTTPS host for production using `--dart-define=API_BASE_URL=...`. Do not put `your_laptop_ip` in the build. Test real Android notifications, logout, support forms, deadline edge cases, referrals, offline 24-hour transitions, local data preservation and password reset email.

## Verification status at packaging

- ZIP integrity and file manifest can be checked locally.
- Python syntax compile check **passed**.
- Full Django migration/test execution **not available** in build environment (dependencies unavailable and network install blocked).
- Flutter SDK not present; Flutter `analyze`, tests, APK build and physical Android performance NOT performed.
- Therefore: **development candidate, not launch-ready**. No outcome is guaranteed until the install/test gate passes.

## Performance strategy

Use native Flutter visuals, offline-local note storage, request-only sync on edits plus infrequent safety polling, bounded uploads, cached aggregate readouts and a small Django/PostgreSQL deployment before adding scaling infrastructure. Measure requests per active user, p95 latency, DB write rate and costs; A fixed naira budget cannot guarantee arbitrary scale.
