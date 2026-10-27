import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser, verifyWalletPin } from '../_shared/supabase.ts';

type Body = {
  recipientId?: string;
  amountMinor?: number;
  pin?: string;
  note?: string;
  idempotencyKey?: string;
};

// Limits are stored in minor units (1 ETB = 100). They are deliberately
// conservative for the demo and can be moved to a limits table later.
const TIER_LIMITS: Record<number, { perTxn: number; daily: number }> = {
  0: { perTxn: 200_000, daily: 500_000 },
  1: { perTxn: 2_000_000, daily: 10_000_000 },
  2: { perTxn: 20_000_000, daily: 100_000_000 },
};

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { client, user } = await requireUser(req);
    const body = await readJson<Body>(req);
    const amount = Number(body.amountMinor);
    const pin = String(body.pin ?? '');
    const idempotencyKey = String(body.idempotencyKey ?? '').trim();

    if (!isUuid(body.recipientId)) return fail('recipientId must be a UUID');
    if (!Number.isSafeInteger(amount) || amount <= 0) return fail('amountMinor must be a positive integer');
    if (!/^\d{4,6}$/.test(pin)) return fail('PIN must be 4 to 6 digits');
    if (!idempotencyKey || idempotencyKey.length > 128) return fail('idempotencyKey is required');

    if (!(await verifyWalletPin(client, pin))) {
      return fail('Incorrect PIN', 401, 'invalid_pin');
    }

    const admin = adminClient();
    const { data: kyc } = await admin
      .from('kyc')
      .select('tier,status')
      .eq('user_id', user.id)
      .maybeSingle();
    const tier = kyc?.status === 'approved' ? Number(kyc.tier ?? 0) : 0;
    const limits = TIER_LIMITS[tier] ?? TIER_LIMITS[0];
    if (amount > limits.perTxn) {
      return fail('Amount exceeds your transaction limit', 403, 'limit_exceeded');
    }

    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const { data: today } = await admin
      .from('transactions')
      .select('amount_minor')
      .eq('user_id', user.id)
      .eq('type', 'p2p')
      .eq('status', 'success')
      .gte('created_at', dayStart.toISOString());
    const spent = (today ?? []).reduce((sum, row) => sum + Number(row.amount_minor), 0);
    if (spent + amount > limits.daily) {
      return fail('Daily transfer limit reached', 403, 'daily_limit_exceeded');
    }

    const { data, error } = await admin.rpc('wallet_transfer', {
      p_recipient: body.recipientId,
      p_amount_minor: amount,
      p_idempotency_key: idempotencyKey,
      p_note: body.note ?? null,
      p_sender: user.id,
    });
    if (error) return fail(error.message, 409, 'transfer_failed');
    return json({ transactionId: data });
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Transfer failed', 401, 'unauthorized');
  }
});
