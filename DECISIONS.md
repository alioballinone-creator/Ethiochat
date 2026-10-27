# Decisions Log

- **Fonts**: use variable Inter and Noto Sans Ethiopic TTFs to minimise bundle size.
- **Gold usage**: reserved for primary actions, logo, wallet card, selected tab indicator. Gold-on-cream text is forbidden (black on gold).
- **Sequence**: gapless `seq` per conversation via `SELECT ... FOR UPDATE` on `conversations.seq_counter`.
- **Outbox**: FIFO, exponential backoff + jitter, max 10 attempts, surfaces "Tap to retry" on failure.
- **Single source of truth**: Drift DB; network sync only.

## Phase 2
- E2EE: design for X3DH + Double Ratchet (X25519, AES-256-GCM, HKDF). Keys in flutter_secure_storage; devices.prekeys hold public prekeys only. messages.body supports ciphertext. Group uses sender keys.
- Calls: LiveKit signalling via Supabase Realtime, ringing via high-priority FCM + flutter_callkit_incoming. TURN over TCP/443. Opus DTX/FEC, audio-only fallback <60kbps.
- Search: Drift FTS5 with Ge'ez-aware normalization (folding) for Amharic/Tigrinya.
- Voice notes: Opus, waveform, hold-to-record, slide-to-cancel, lock.

## Phase 3
- Wallet: double-entry ledger, immutable entries (no UPDATE/DELETE). Balances derived from sum.
- Money movement only via Edge Functions with service role. Client never writes ledger.
- Idempotency keys on all money ops. PIN hashed with Argon2, rate-limited.
- Payment providers behind interface: Telebirr, CBE Birr, Chapa. Webhook signature verification.
- Red packets: double-mean split, atomic claim with SELECT ... FOR UPDATE SKIP LOCKED, expiry refunds.

## Phase 4
- Moments: friends-only, visibility controls, mutual-only likes/comments, keyset pagination.
- Channels: vertical swipe, preload next 2, data-saver 360p, resumable upload.
- Official Accounts: verified, subscription feed, in-chat menu.
- Mini Programs: signed bundles, sandboxed WebView, whitelisted permission-gated bridge, offline cache.

## Phase 5
- Marketplace and nearby features with privacy controls.
- Growth features implemented with consent.

## Later implementation decisions
- Wallet ships hidden behind `--dart-define=ENABLE_WALLET=true` until the
  backend is deployed and provider sandbox tests pass. The local ledger remains
  the UI source of truth in demo mode.
- Wallet mutations are Edge-Function-only. The SQL RPCs require an explicit
  service-role caller and sender/claimer id, so a compromised client cannot
  mint ledger entries even if it calls PostgREST directly.
- PINs use bcrypt cost 12 through `pgcrypto`; Argon2id is deferred until a
  supported deployment path exists. This is documented in `SECURITY.md`.
- `record` is pinned to `^6.2.1`; version 7 requires Flutter 3.44 while CI uses
  3.35.4, and the 5.x line selected an incompatible `record_linux`.
- Framework localisations fall back to English for locales Flutter does not
  ship. App content copy remains English until the ARB files are translated.
- Android `FLAG_SECURE` is applied through a native method channel only while a
  wallet/PIN screen is mounted, using a reference count to survive nested routes.
