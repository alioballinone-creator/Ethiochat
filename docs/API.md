# Edge Function API

All functions are deployed under
`https://<project-ref>.supabase.co/functions/v1/<function>`. Except for the
payment webhook, requests require `Authorization: Bearer <user access token>`.
Errors use `{ "error": { "code": "...", "message": "..." } }`.

## `wallet-transfer`

`POST /wallet-transfer`

```json
{
  "recipientId": "uuid",
  "amountMinor": 25000,
  "pin": "123456",
  "note": "Lunch",
  "idempotencyKey": "client-generated-uuid"
}
```

Verifies the PIN, checks KYC tier limits and the daily P2P total, then calls the
service-role `wallet_transfer` RPC with `p_sender` set to the authenticated user.
Returns `{ "transactionId": "uuid" }`. Reusing an idempotency key returns the
original transaction.

## `wallet-redpacket`

`POST /wallet-redpacket`

Create:

```json
{
  "action": "create",
  "conversationId": "uuid-or-null",
  "totalMinor": 10000,
  "count": 5,
  "mode": "random",
  "pin": "123456",
  "idempotencyKey": "client-generated-uuid"
}
```

Claim:

```json
{ "action": "claim", "redpacketId": "uuid" }
```

Create requires a PIN and returns `{ "redpacketId": "uuid" }`; claim returns the
claimed `{ "amountMinor": 1234 }`.

## `payment-webhook`

`POST /payment-webhook` with header
`x-ethiochat-signature: sha256=<hex hmac>` where the HMAC key is
`PAYMENT_WEBHOOK_SECRET` and the payload is the raw request body.

```json
{
  "event": "payment.succeeded",
  "status": "success",
  "provider": "telebirr",
  "providerRef": "provider-reference",
  "userId": "uuid",
  "amountMinor": 10000,
  "idempotencyKey": "provider-event-id",
  "timestamp": 1760000000
}
```

Only `payment.succeeded` is processed. Timestamps older/newer than five minutes
are rejected; idempotency keys are enforced by the ledger RPC. The function must
be configured as a provider webhook with signature verification enabled.

## `contact-discovery`

`POST /contact-discovery`

```json
{ "hashes": ["sha256-hex", "..."] }
```

Accepts at most 500 lowercase SHA-256 hashes of E.164 phone numbers (the same
normalisation used for `profiles.phone_hash`) and returns only matching profile
cards. Raw phone numbers and stored hashes are never returned. A server-issued
pepper and endpoint-level rate limiting are required before production use.

## Required secrets

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
`PAYMENT_WEBHOOK_SECRET`. Provider/FCM/LiveKit secrets are added only when those
adapters are deployed.
