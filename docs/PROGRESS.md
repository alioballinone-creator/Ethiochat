# Progress

## Complete
- [x] Design system, themes, five UI locales with English fallbacks
- [x] Supabase migrations through phase 6 and Edge Functions
- [x] Drift schema, repositories, outbox/backoff and seed data
- [x] Authenticated Supabase message sends with idempotency and media uploads
- [x] Conversation/message hydration, realtime inserts and signed media URLs
- [x] Supabase phone OTP when configured; deterministic demo OTP otherwise
- [x] App shell, chats, groups, contacts, search, QR and settings
- [x] Chat media, voice notes, replies, forwarding, editing and drafts
- [x] Local moments persistence with likes and comments
- [x] Wallet ledger, RPCs, PIN flow and screens behind the wallet flag
- [x] Format, analyze, full unit/widget suite and release APK/AAB in CI
- [x] Security, API, Edge Function and pgTAP documentation

## In progress
- [ ] Add delivery/read receipts, remote edit/delete propagation and resumable
  media uploads
- [ ] LiveKit calls and FCM ringing/delivery
- [ ] Full ARB translations, Ethiopian calendar and locale golden tests
- [ ] Deploy migrations/functions and run pgTAP against a scratch project

## Explicitly not shipped
- [ ] X3DH/Double Ratchet E2EE (schema only; no client implementation claimed)
- [ ] Server-side account deletion and data export beyond the local device
- [ ] Provider sandbox certification and production wallet enablement
