# Supabase Edge Functions

| Function | Auth | Purpose |
| --- | --- | --- |
| `wallet-transfer` | user JWT + PIN | validate limits, verify PIN, service-role transfer |
| `wallet-redpacket` | user JWT (+PIN to create) | create/claim red packets atomically |
| `payment-webhook` | HMAC signature | verify provider replay-safe top-ups |
| `contact-discovery` | user JWT | match salted phone hashes without uploading raw contacts |

Deploy with `supabase functions deploy` after setting the secrets listed in
`docs/API.md`. `wallet-transfer`, `wallet-redpacket` creation and claims are
revoked from the `authenticated` role at the database level; do not re-grant
them directly to clients.

The shared `_shared/http.ts` module provides CORS and typed JSON errors.
`_shared/supabase.ts` handles user/admin clients and PIN verification.

Local smoke test (requires the Supabase CLI and Docker):

```sh
supabase start
supabase functions serve wallet-transfer --env-file .env
curl -i -X OPTIONS http://127.0.0.1:54321/functions/v1/wallet-transfer
```
