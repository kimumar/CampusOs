# CampusOS M03-A — Backend foundation (development candidate)

This is **stage A only**, not the finished M03 release. It adds a Django REST API without changing the current Flutter application, its Hive records, or the M02 profile.

## What is included
- Email/password registration and email verification
- Server-timestamped 7-day trial beginning on verification
- Login and short-lived JWT access tokens
- Password reset request and confirmation
- Account-scoped student profile endpoints
- Unit tests for registration, verification, expiry and profile isolation
- PostgreSQL configuration through `DATABASE_URL`; local SQLite fallback for development

## Important limitations
- No Flutter login screens or account gate yet; the current app remains accessible.
- No subscription checkout or payment webhook. `paid_until` is a placeholder for a later server-verified billing integration.
- No academic-record sync, entitlement protection on academic endpoints, or offline entitlement cache yet.
- The default email backend prints links to the server console for local development. Configure real SMTP before public testing.
- The API uses Django's default verification-token lifetime (configured by Django); link pages on Flutter Web are not yet implemented.
- Basic throttling is **not sufficient** for internet-facing brute-force protection. Add edge rate limiting, monitoring, and anti-abuse before public deployment.
- Do not deploy without a strong secret, verified HTTPS, real email delivery, backup/restore testing and database migrations.
- Free hosting providers may change their terms and limits.

## Local setup (Windows PowerShell)
From `CampusOS\backend`:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:DJANGO_DEBUG = '1'
$env:DJANGO_SECRET_KEY = 'local-development-only-not-for-production'
.\.venv\Scripts\python.exe manage.py makemigrations accounts
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py test
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Local development uses SQLite if `DATABASE_URL` is not configured. **Migrations are generated locally** in this stage; review and commit the generated migration before deploying to PostgreSQL. Never use `makemigrations` automatically on a production server.

## API endpoints
- POST `/api/v1/auth/register/` — `email`, `password`
- POST `/api/v1/auth/verify-email/` — `uid`, `token`
- POST `/api/v1/auth/login/` — `email`, `password`
- POST `/api/v1/auth/refresh/` — `refresh`
- GET `/api/v1/auth/me/` — Bearer token
- GET/PATCH `/api/v1/auth/profile/` — Bearer token
- POST `/api/v1/auth/password-reset/` — `email`
- POST `/api/v1/auth/password-reset/confirm/` — `uid`, `token`, `password`
- GET `/health/`

## M03 acceptance
M03-A is complete only after dependencies install, migrations run and tests pass on the laptop. M03-B will integrate Flutter authentication and a registration gate; M03-C will implement enforceable entitlement access and offline restrictions.
