import { fail, env, isUuid, json, preflight } from '../_shared/http.ts';
import { adminClient } from '../_shared/supabase.ts';

type Body = {
  event?: string;
  status?: string;
  provider?: string;
  providerRef?: string;
  userId?: string;
  amountMinor?: number;
  idempotencyKey?: string;
  timestamp?: number;
};

async function validSignature(raw: string, header: string | null): Promise<boolean> {
  if (!header) return false;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(env('PAYMENT_WEBHOOK_SECRET')),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  const given = header.replace(/^sha256=/i, '').toLowerCase();
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const raw = await req.text();
  if (!(await validSignature(raw, req.headers.get('x-ethiochat-signature')))) {
    return fail('Invalid signature', 401, 'invalid_signature');
  }

  try {
    const body = JSON.parse(raw) as Body;
    if (body.event !== 'payment.succeeded' || body.status !== 'success') {
      return json({ ok: true, ignored: true });
    }
    if (body.timestamp && Math.abs(Date.now() / 1000 - body.timestamp) > 300) {
      return fail('Webhook timestamp is outside the replay window', 401, 'replay');
    }
    if (!isUuid(body.userId)) return fail('userId must be a UUID');
    if (!Number.isSafeInteger(body.amountMinor) || Number(body.amountMinor) <= 0) {
      return fail('amountMinor must be positive');
    }
    const provider = String(body.provider ?? 'unknown').slice(0, 40);
    const providerRef = String(body.providerRef ?? '').slice(0, 200);
    const idempotencyKey = String(body.idempotencyKey ?? '').trim();
    if (!idempotencyKey) return fail('idempotencyKey is required');

    const { data, error } = await adminClient().rpc('wallet_topup', {
      p_user: body.userId,
      p_amount_minor: body.amountMinor,
      p_idempotency_key: idempotencyKey,
      p_provider: provider,
      p_provider_ref: providerRef || null,
    });
    if (error) return fail(error.message, 409, 'topup_failed');
    return json({ transactionId: data });
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Webhook failed', 400, 'bad_request');
  }
});
