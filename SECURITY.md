# Security

- RLS enabled on every table. Service role only for ledger/wallet Edge Functions.
- Phone numbers hashed on-device before contact discovery matching.
- Certificate pinning planned; root/jailbreak warnings; `FLAG_SECURE` on wallet/PIN.
- Idempotency keys on all money movement; double-entry immutable ledger.
- E2EE (X3DH + Double Ratchet, sender keys) designed for Phase 2.
