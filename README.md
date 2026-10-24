# EthioChat

EthioChat is a WeChat-class super-app for Ethiopia and the Horn of Africa: messaging, calls, social feed, channels, official accounts, mini programs and a mobile wallet in one app. Built with Flutter (Dart 3), Riverpod, Drift, and Supabase, with an offline-first outbox and a gold/cream Ethiopian design system.

## Quick setup (10 minutes)
1. Install Flutter 3.35+ and Dart 3.5+.
2. `cp .env.example .env` and fill in Supabase/FCM/SMS/payment credentials when ready.
3. `flutter pub get && dart run build_runner build --delete-conflicting-outputs`
4. `make dev` to run on a connected device/emulator.

## Phase 1 (MVP) scope
- Auth (phone OTP + profile), contacts
- 1:1 and group text chat
- Offline-first outbox with exponential backoff + jitter
- Push notifications (FCM), theming (light/dark), i18n (en, am, om, ti, so)
- Local Drift DB as single source of truth

## Commands
- `make gen` – regenerate freezed/drift/riverpod
- `make analyze` – static analysis
- `make test` – unit/widget tests
- `make build-apk` – release APK (obfuscated, split ABI)

## Architecture
Clean architecture, feature-first (`lib/core`, `lib/features/*/{data,domain,presentation}`), typed `Failure`/`Result`, RLS on all tables, per-conversation sequence via Postgres trigger.

## Security notes
- Only the Supabase anon key goes in the client.
- Service role keys live in Edge Function secrets only.
- Wallet ledger is double-entry and immutable (no UPDATE/DELETE grants).
- See `SECURITY.md` for details.

## Status
Phase 1 scaffold complete. Run `make analyze` and `make test` as you iterate.
