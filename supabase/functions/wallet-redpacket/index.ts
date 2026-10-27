import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser, verifyWalletPin } from '../_shared/supabase.ts';

type CreateBody = {
  action: 'create';
  conversationId?: string | null;
  totalMinor?: number;
  count?: number;
  mode?: 'random' | 'equal';
  pin?: string;
  idempotencyKey?: string;
};
type ClaimBody = { action: 'claim'; redpacketId?: string };

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { client, user } = await requireUser(req);
    const body = await readJson<CreateBody | ClaimBody>(req);
    const admin = adminClient();

    if (body.action === 'claim') {
      if (!isUuid(body.redpacketId)) return fail('redpacketId must be a UUID');
      const { data, error } = await admin.rpc('wallet_claim_redpacket', {
        p_redpacket: body.redpacketId,
        p_claimer: user.id,
      });
      if (error) return fail(error.message, 409, 'claim_failed');
      return json({ amountMinor: data });
    }

    if (body.action !== 'create') return fail('action must be create or claim');
    const total = Number(body.totalMinor);
    const count = Number(body.count);
    const mode = body.mode === 'equal' ? 'equal' : 'random';
    const pin = String(body.pin ?? '');
    const idempotencyKey = String(body.idempotencyKey ?? '').trim();
    if (!Number.isSafeInteger(total) || total <= 0) return fail('totalMinor must be positive');
    if (!Number.isSafeInteger(count) || count <= 0 || count > 500) return fail('count must be 1..500');
    if (total < count) return fail('Each share must be at least 0.01 ETB');
    if (!/^\d{4,6}$/.test(pin)) return fail('PIN must be 4 to 6 digits');
    if (!idempotencyKey) return fail('idempotencyKey is required');
    if (body.conversationId && !isUuid(body.conversationId)) return fail('conversationId must be a UUID');

    if (!(await verifyWalletPin(client, pin))) {
      return fail('Incorrect PIN', 401, 'invalid_pin');
    }

    const { data, error } = await admin.rpc('wallet_create_redpacket', {
      p_conversation: body.conversationId ?? null,
      p_total_minor: total,
      p_count: count,
      p_mode: mode,
      p_expires_in: '24 hours',
      p_idempotency_key: idempotencyKey,
      p_sender: user.id,
    });
    if (error) return fail(error.message, 409, 'create_failed');
    return json({ redpacketId: data });
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Red packet failed', 401, 'unauthorized');
  }
});
