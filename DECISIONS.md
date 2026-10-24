# Decisions Log

- **Fonts**: use variable Inter and Noto Sans Ethiopic TTFs to minimise bundle size.
- **Gold usage**: reserved for primary actions, logo, wallet card, selected tab indicator. Gold-on-cream text is forbidden (black on gold).
- **Sequence**: gapless `seq` per conversation via `SELECT ... FOR UPDATE` on `conversations.seq_counter`.
- **Outbox**: FIFO, exponential backoff + jitter, max 10 attempts, surfaces "Tap to retry" on failure.
- **Single source of truth**: Drift DB; network sync only.
