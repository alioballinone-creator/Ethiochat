# Architecture

## Principles
- Offline-first: UI reads from Drift; network syncs into it.
- Clean architecture, feature-first.
- Typed errors (`core/errors/failure.dart`), `Result<T>` for repositories.
- All Postgres tables have RLS; least privilege.
- Per-conversation gapless sequence assigned by `assign_message_seq()`.

## Data flow (messaging)
1. UI enqueues message → write to Drift `messages` (status pending) + `outbox`.
2. `OutboxWorker` uploads media (resumable), inserts message, retries with exponential backoff + jitter (cap 60s).
3. Realtime syncs deltas; gap detection fetches missing `seq` ranges.
4. Receipts update ticks (sent/delivered/read).

## Structure
```
lib/
  core/{theme,l10n,network,db,errors,utils,crypto,logging}
  features/*/{data,domain,presentation}
  app.dart main.dart
supabase/{migrations,functions,tests,seed}
```
