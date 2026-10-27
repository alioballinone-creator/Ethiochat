# Security model

## Roles and data access
- Supabase RLS is enabled on every application table. Clients authenticate with
  the `authenticated` role; the anon key alone grants no row access. Phone login
  uses Supabase Auth OTP when the app is built with Supabase credentials; the
  credential-free demo build accepts any six digits and must not be shipped.
- Conversations are visible only to members. `send_message` is `SECURITY
  INVOKER` so restrictive message policies and blocking rules are always
  evaluated.
- Direct-chat sends are rejected when either participant has blocked the other.
  Group broadcasts are restricted to owners/admins.
- Reports and audit rows are insert-only for users; only service roles can read
  the moderation queue.

## Money
- `wallets`, `ledger_entries`, `transactions`, `redpackets` and
  `redpacket_claims` are service-role-only for writes. `ledger_entries` is
  append-only; there are no UPDATE/DELETE grants.
- Clients cannot call `wallet_transfer`, `wallet_create_redpacket` or
  `wallet_claim_redpacket` directly. The RPCs are revoked from `authenticated`
  and granted to `service_role` only. Edge Functions authenticate the user,
  verify the PIN, enforce limits and then pass an explicit sender/claimer id.
- PINs are stored as bcrypt hashes with cost 12 (`pgcrypto`). Verification and
  attempt counts happen in SQL; five failures lock the wallet for 15 minutes.
  Edge Functions never log PINs. Argon2id remains the target once a supported
  Postgres extension or Edge hashing path is available.
- Payment webhooks require an HMAC-SHA-256 signature over the raw body and a
  timestamp within five minutes. Provider event ids are persisted for replay
  rejection.
- Wallet and PIN screens set Android `FLAG_SECURE`, blocking screenshots and
  screen recording.

## Content and storage
- Private buckets are used for chat media, moments, avatars and verification
  documents. Storage policies require conversation membership or ownership.
- Soft-deleted messages are purged by a daily `pg_cron` job; red packets are
  refunded after expiry.
- Contact discovery uploads only SHA-256 hashes of normalised phone numbers and
  returns profile cards. Raw phone numbers and stored hashes are never returned.
  A server pepper, endpoint rate limiting and abuse monitoring are required
  before production use.

## Secrets and operations
- The service-role key exists only as a Supabase Edge Function secret. Never
  place it in Flutter, `--dart-define`, git or logs.
- `SUPABASE_ANON_KEY`, analytics keys and SMS/payment sandbox keys come from CI
  secrets or `.env` (gitignored).
- Deployments run through the Supabase workflow after project-ref/access-token
  secrets are configured. Audit logs record admin actions.
- Known pre-launch gaps: certificate pinning, root/jailbreak attestation, full
  E2EE Double Ratchet, OTP rate-limit tuning against the chosen SMS provider,
  and an independent security review.
