import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = {
  action?: 'report' | 'review';
  targetType?: string;
  targetId?: string;
  targetName?: string;
  reason?: string;
  note?: string;
  reportId?: string;
  status?: string;
};

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const body = await readJson<Body>(req);
    const admin = adminClient();

    if (body.action === 'report') {
      if (!body.targetType || !body.targetId) {
        return fail('targetType and targetId are required');
      }
      if (!body.reason || body.reason.trim().length === 0) {
        return fail('A reason is required');
      }
      const { data, error } = await admin
        .from('reports')
        .insert({
          reporter_id: user.id,
          target_type: body.targetType,
          target_id: String(body.targetId),
          target_name: body.targetName?.trim() || null,
          reason: body.reason.trim(),
          note: body.note?.trim() || null,
          status: 'open',
        })
        .select('id')
        .single();
      if (error) throw new Error(error.message);
      return json({ reportId: data.id });
    }

    if (body.action === 'review') {
      const { data: adminRow } = await admin
        .from('admin_users')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
      if (!adminRow) return fail('Admin privileges required', 403, 'forbidden');

      if (!isUuid(body.reportId)) return fail('reportId is required');
      const status = body.status ?? 'reviewing';
      if (!['open', 'reviewing', 'resolved', 'dismissed'].includes(status)) {
        return fail('Invalid status');
      }

      const { error } = await admin
        .from('reports')
        .update({
          status,
        })
        .eq('id', body.reportId);
      if (error) throw new Error(error.message);
      return json({ ok: true });
    }

    return fail('action must be report or review');
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Moderation failed', 401, 'unauthorized');
  }
});
