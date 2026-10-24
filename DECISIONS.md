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
