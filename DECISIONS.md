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
