# AI Development Rules — CampusOS

Permanent development instructions for all future AI coding sessions on the CampusOS repository.

## A. Development Workflow

Follow this sequence for every task:

**Inspect → Plan → Implement → Test → Fix → Document → Checkpoint**

1. **Inspect**: Read existing code, configuration, and Git state before making changes.
2. **Plan**: Define the scope, files affected, and verification steps.
3. **Implement**: Make minimal, targeted changes aligned with existing conventions.
4. **Test**: Run relevant automated checks (`flutter analyze` for Flutter; backend tests for Django).
5. **Fix**: Investigate and resolve any failures before proceeding.
6. **Document**: Update `DEVELOPMENT_LOG.md` at every milestone.
7. **Checkpoint**: Commit and request approval before pushing to GitHub.

Complete the agreed scope for each milestone before beginning another. Avoid unnecessary repeated inspections and tool calls.

## B. Architecture

CampusOS is an offline-first academic productivity SaaS for Nigerian university students.

Intended architecture:
- **Flutter/Dart** for Android, iOS, and web (mobile prototype in `mobile/`).
- **Riverpod** for application state management (planned, not yet implemented).
- **Django REST Framework** for the backend (planned, not yet implemented).
- **PostgreSQL** for server-side persistence (planned, not yet implemented).
- **Drift/SQLite** as the planned native offline storage layer (planned).
- **Hive CE** is the existing local storage in the Flutter prototype; preserve it until a safe, tested migration is implemented.
- Secure account authentication and synchronization.
- Modular architecture with independently usable but interconnected features.

Do not assume planned technologies are already installed or implemented. Do not introduce microservices or unnecessary architectural complexity.

## C. Data Protection

- Never silently discard user data.
- Preserve existing Hive CE records.
- Future database migrations must include backward compatibility, migration tests, and recovery considerations.
- Cloud synchronization must eventually support account isolation, conflict handling, idempotency, and offline retries.

## D. Feature Preservation

- Existing features must continue working after every milestone.
- Do not rewrite unrelated modules.
- Keep Course Management, Timetable, Notes, and other modules independently usable where practical.
- Use shared reusable components instead of duplicating UI logic.

## E. UI Standards

- Preserve the existing premium CampusOS visual identity.
- Use responsive, accessible layouts.
- Forms must be keyboard-aware and usable on small Android screens.
- Do not introduce unnecessary design changes outside the milestone scope.

## F. Security

- Never hardcode passwords, API keys, payment credentials, or secrets.
- Do not commit `.env` files containing secrets.
- Use secure authentication and server-side authorization.
- Treat student academic data as private.

## G. Testing

- Run relevant automated checks after modifying code.
- For Flutter changes: run `flutter analyze` and applicable tests from the `mobile/` directory.
- For future Django changes: run relevant backend tests and system checks.
- Investigate failures before declaring completion.
- Do not hide errors or modify tests merely to force them to pass.

## H. GitHub Workflow

- Use the existing CampusOS repository (`https://github.com/kimumar/CampusOS.git`).
- Preserve Git history.
- Never force-push or use destructive Git commands without explicit permission.
- Commit only intended project files.
- Update `DEVELOPMENT_LOG.md` at every milestone.
- Request approval before pushing to GitHub unless the user explicitly authorizes that push.

## I. Reporting

Every milestone report must contain:
- Work completed.
- Files created or modified.
- Tests performed and results.
- Known issues.
- Git commit ID.
- Push status.
- Recommended next milestone.

Never claim completion without verification.
