# Hybrid Pro Admin (Flutter)

Coach admin mobile app for Hybrid Pro. Talks directly to `hybrid-pro-api` (`/api/admin/*`) with a coach JWT — not the Next.js website BFF.

## Features

- Coach email/password login
- Clients: stats, search/filters, grant plan, detail (extend / change / cancel)
- Coach desk: notes, check-ins, replies
- Assign workout (app-linked clients)
- Exercises CRUD
- Payments ledger
- Contact inbox + grant plan

## Prerequisites

- Flutter SDK (3.13+)
- Running [hybrid-pro-api](../hybrid-pro-api) (default `http://localhost:3002`)
- Coach credentials from API env: `COACH_EMAIL` / `COACH_PASSWORD`

## Run

```bash
cd hybrid-pro-admin

# Local API (simulator / emulator). This is the default.
flutter run

# Physical device → your machine LAN IP
flutter run --dart-define=HYBRID_BACKEND_URL=http://192.168.x.x:3002

# Production API
flutter run --dart-define=HYBRID_BACKEND_URL=https://api.hybridpro.in
```

`flutter run` uses `http://localhost:3002`. `./scripts/run_dev.sh` does the same.

## Project layout

- `lib/core/` — config, Dio client, auth, models, repository
- `lib/features/` — auth, clients, exercises, payments, contacts, shell
- `lib/widgets/` — shared UI

## Notes

- Keep the existing web `/admin` until this app is validated.
- Client (member) Flutter migration is separate and out of scope here.
- Android Gradle: the wrapper uses a direct mirror (`mirrors.cloud.tencent.com`) because `services.gradle.org` redirects to GitHub CDN and often times out in Java on some networks. First Android build still downloads ~130MB once.
