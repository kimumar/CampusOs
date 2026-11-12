# CampusOS Update 015 — consolidated source update

## Scope
- Update 013, the previously delivered 013 test-fix patch, and the 014 reset/notifications/copy patch have been incorporated.
- Owner-friendly dark-mode Business Control Centre at `/control/` (superuser access only), linked from Django Admin. Existing admin edit forms remain the actual source of truth.
- Default WhatsApp TV partner first-payment commissions: **₦200 monthly / ₦450 quarterly**. Both rates editable globally and separately per partner (including ₦0). No renewals, no rewards for complimentary accounts, no retrospective repricing.
- Automatically created student invitation code at registration, read-only unique student code and referral link in Profile → Invite Friends; student invitations generate **no commission**.
- Profile → Change Password validates current password and Django strength rules.
- Prior reset-password phone page and Android notification history fix carried forward.

## Important limitations
- The shareable student referral link is based on the current server address. Production requires a real HTTPS landing page and mobile deep links. Development links are not publicly accessible.
- No live payment provider is configured. An admin action **does not** prove that money was actually settled. Verify independently before activation.
- This source archive is NOT a verified Android APK. Run Flutter analysis/tests and Django checks/tests on your Windows PC.
- Original PDFs/images must remain **local only** and never be added to academic sync. The next dedicated sync/storage optimization must be separately verified before declaring a guaranteed local-only policy throughout all import pipelines.
- Change-only uploads now use compact per-account local fingerprints. Full server-state download, six-month cleanup, background notification delivery on every OEM device, and production-verified reset email still require further optimization or end-to-end verification. Do not claim those are done just from a source archive.

## Safe installation
1. Close Flutter and Django processes. Back up the existing project and SQLite database BEFORE installation.
2. Run `INSTALL_UPDATE_015.ps1` from the extracted archive. It copies source files, does not erase existing local databases, does not automatically migrate, and rolls back source on copy failure.
3. In backend venv: `python manage.py check`; `python manage.py makemigrations --check --dry-run`; `python manage.py test`; `python manage.py migrate --plan`. Inspect and back up database before `python manage.py migrate`.
4. In mobile: `flutter pub get`; `flutter analyze`; `flutter test`; build using the verified phone-reachable backend IP (never `localhost` on Android).
5. Test new signup, unique student code, referral attribution, no cash reward for student, TV rewards for both plans, password change, password reset link on phone, bell, sync, local-only PDF/image behavior.

## Git
Commit a checkpoint only after the user's laptop checks and real-device tests succeed. Do not upload secrets or SQLite backups to Git.
