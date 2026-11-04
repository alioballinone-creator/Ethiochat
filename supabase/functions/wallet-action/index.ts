import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = {
  action?: 'topup' | 'bill' | 'request' | 'purchase';
  amountMinor?: number;
  provider?: string;
  accountRef?: string;
  note?: string;
  pin?: string;
  idempotencyKey?: string;
};

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { client, user } = await requireUser(req);
    const body = await readJson<Body>(req);
    const action = body.action;
    if (!action || !['topup', 'bill', 'request', 'purchase'].includes(action)) {
      return fail('Unsupported wallet action.');
    }
    const amountMinor = Number(body.amountMinor);
    if (!Number.isSafeInteger(amountMinor) || amountMinor < (action === 'request' ? 0 : 1)) {
      return fail('Amount must be valid.');
    }
    const idempotencyKey = body.idempotencyKey?.trim() ?? '';
    if (!isUuid(idempotencyKey)) return fail('A valid idempotency key is required.');

    const admin = adminClient();
    const { data: existing, error: existingError } = await admin.from('transactions')
      .select('id,user_id,status,type,amount_minor,created_at')
      .eq('idempotency_key', idempotencyKey).maybeSingle();
    if (existingError) throw new Error('Transaction status is unavailable.');
    if (existing) {
      if (existing.user_id && existing.user_id !== user.id) return fail('Transaction key already used.', 409);
      return json({ transaction: existing, enabled: false });
    }

    const type = action === 'request'
      ? 'request'
      : action === 'purchase'
        ? 'merchant'
        : action;
    const status = action === 'request' ? 'pending' : 'failed';
    const metadata: Record<string, unknown> = {
      source: 'wallet-action',
      note: body.note?.trim().slice(0, 160) || null,
    };
    if (action === 'bill') {
      metadata.account_ref = body.accountRef?.trim().slice(0, 120) || null;
    }

    const { data: transaction, error } = await admin.from('transactions').insert({
      user_id: user.id,
      created_by: user.id,
      type,
      status,
      amount_minor: amountMinor,
      provider: body.provider?.trim().slice(0, 80) || null,
      idempotency_key: idempotencyKey,
      meta: metadata,
    }).select('id,status,type,amount_minor,created_at').single();
    if (error) throw new Error('Transaction could not be recorded.');

    if (action === 'request') {
      return json({ transaction, enabled: true });
    }
    return json({
      transaction,
      enabled: false,
      message: action === 'topup'
        ? 'Payments are not enabled yet. No funds were added.'
        : action === 'bill'
          ? 'Bill payments are not enabled yet. No funds were taken.'
          : 'Purchases are not enabled yet. No funds were taken.',
    });
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Wallet action failed.', 400);
  }
});
