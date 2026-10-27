# EthioChat

EthioChat is a WeChat-class super-app for Ethiopia and the Horn of Africa:
messaging, calls, moments, channels, official accounts, mini programs and a
wallet in one Flutter app. The UI is local-first through Drift; Supabase adds
accounts, sync, row-level security, money RPCs and Edge Functions.

## Quick setup (10 minutes)

1. Install Flutter 3.35+ / Dart 3.5+ and the Supabase CLI.
2. `cp .env.example .env` and fill in Supabase, SMS, FCM and payment sandbox
   credentials when available.
3. `flutter pub get && dart run build_runner build --delete-conflicting-outputs`
4. `make dev` for a connected device, or `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
5. Backend: `supabase link --project-ref <ref> && supabase db push` and
   `supabase functions deploy`.

The app opens in demo mode without Supabase credentials. Demo content is seeded
into the local database on first launch.

## What is implemented

- Gold/cream design system, light/dark themes, five UI locales (`en`, `am`,
  `om`, `ti`, `so`). Framework strings fall back to English where Flutter has no
  Material translation.
- Phone entry, OTP UI, profile setup, shell navigation, chats, groups, contacts,
  requests, search, QR, moments, channels, official accounts, mini programs,
  nearby, scan, calls, report/block, onboarding and the full settings tree.
- Offline-first Drift schema, outbox/backoff state machine, message status,
  reply/forward/edit/delete, voice notes, attachments, drafts and local search.
- Wallet ledger and wallet screens (send, receive, top-up, bills, history,
  receipts, red packets, PIN) behind `--dart-define=ENABLE_WALLET=true`.
- Supabase migrations through phase 6: RLS, contact discovery database support,
  sequence trigger, message/moment policies, reports/blocks/audit/feature flags,
  storage buckets, pg_cron jobs and wallet RPCs.
- Edge Functions: wallet transfer, red-packet create/claim, signed provider
  payment webhook and privacy-preserving contact discovery.

## Commands

- `make gen` – regenerate freezed/drift/riverpod output
- `make analyze` – static analysis
- `make test` – unit and widget tests
- `make build-apk` – obfuscated release APK, split per ABI
- `make supabase-test` – pgTAP tests against a local Supabase stack
- `make functions-serve` – serve Edge Functions locally

## Architecture and security

See `ARCHITECTURE.md`, `DECISIONS.md`, `SECURITY.md`, `docs/API.md` and
`supabase/functions/README.md`. Ledger rows are immutable; client roles cannot
write them. Wallet mutations run only in service-role Edge Functions. RLS is
enabled on every application table.

## Status and known gaps

The Flutter CI suite (format, analyze, unit/widget tests, release APK/AAB) is the
merge gate. The backend migrations and functions are written but cannot be
deployed in this environment because Supabase project credentials are absent.
Remaining production work:

- Wire the outbox to Supabase realtime/delta sync and authenticated sessions.
  The current worker deliberately simulates transport when no backend session is
  configured, so the offline flow is testable without credentials.
- Replace the call UI simulation with LiveKit rooms, CallKit/ConnectionService
  and push ringing.
- Add FCM delivery, SMS/Telegram OTP fallback and a deployed moderation console.
- Complete the pre-launch E2EE work (the schema and privacy copy are ready; the
  X3DH/Double Ratchet implementation is intentionally not claimed as shipped).
- Add full translated ARB strings, Ethiopian calendar pickers and golden tests in
  every locale.
- Apply migrations to a scratch project/run pgTAP, then run real-device QA and
  provider sandbox tests before enabling wallet by default.
