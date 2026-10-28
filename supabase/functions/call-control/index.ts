import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = {
  callId?: string;
  action?: 'end' | 'reject';
};

type CallRow = {
  id: string;
  conversation_id: string | null;
  caller_id: string;
  callee_id: string | null;
  type: 'voice' | 'video';
  status: string;
  started_at: string | null;
};

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60).toString().padStart(2, '0');
  const secs = Math.max(0, seconds % 60).toString().padStart(2, '0');
  return `${mins}:${secs}`;
}

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const body = await readJson<Body>(req);
    if (!isUuid(body.callId)) return fail('callId must be a UUID');
    if (body.action !== 'end' && body.action !== 'reject') {
      return fail('action must be end or reject');
    }

    const admin = adminClient();
    const { data: found, error } = await admin
      .from('calls')
      .select('id,conversation_id,caller_id,callee_id,type,status,started_at')
      .eq('id', body.callId)
      .maybeSingle();
    if (error) return fail(error.message, 500);
    if (!found) return fail('Call not found', 404, 'not_found');
    const call = found as CallRow;

    let allowed = call.caller_id === user.id || call.callee_id === user.id;
    if (!allowed && call.conversation_id) {
      const { data: membership } = await admin
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', call.conversation_id)
        .eq('user_id', user.id)
        .is('left_at', null)
        .maybeSingle();
      allowed = Boolean(membership);
    }
    if (!allowed) return fail('You are not a participant in this call', 403, 'forbidden');
    if (body.action === 'reject' && call.caller_id === user.id) {
      return fail('The caller cannot reject their own call', 400);
    }
    if (!['ringing', 'accepted'].includes(call.status)) {
      return json({ ok: true, status: call.status, alreadyEnded: true });
    }

    let status: string;
    if (call.status === 'ringing') {
      status = body.action === 'reject'
        ? 'rejected'
        : call.caller_id === user.id
          ? 'missed'
          : 'rejected';
    } else {
      status = 'ended';
    }

    const endedAt = new Date();
    const durationSeconds = call.started_at
      ? Math.max(0, Math.floor((endedAt.getTime() - Date.parse(call.started_at)) / 1000))
      : null;

    const { data: updated, error: updateError } = await admin
      .from('calls')
      .update({
        status,
        ended_at: endedAt.toISOString(),
        duration_seconds: durationSeconds,
      })
      .eq('id', call.id)
      .eq('status', call.status)
      .select('id,conversation_id,caller_id,callee_id,type,status,started_at,duration_seconds')
      .maybeSingle();
    if (updateError) return fail(updateError.message, 500);
    if (!updated) {
      return json({ ok: true, status: 'already_ended', alreadyEnded: true });
    }

    await admin
      .from('call_participants')
      .update({ left_at: endedAt.toISOString() })
      .eq('call_id', call.id)
      .eq('user_id', user.id)
      .is('left_at', null);

    if (call.conversation_id) {
      const mode = call.type === 'video' ? 'Video' : 'Voice';
      const bodyText = updated.status === 'ended'
        ? `${mode} call · ${formatDuration(durationSeconds ?? 0)}`
        : updated.status === 'missed'
          ? `Cancelled ${call.type} call`
          : `Missed ${call.type} call`;
      const { error: messageError } = await admin.from('messages').insert({
        id: crypto.randomUUID(),
        conversation_id: call.conversation_id,
        sender_id: call.caller_id,
        type: 'system',
        body: bodyText,
      });
      if (messageError) {
        // The call itself has ended; report the audit failure rather than
        // pretending the conversation history was updated.
        return fail(
          `Call ended, but the call summary could not be saved: ${messageError.message}`,
          500,
          'summary_failed',
        );
      }
    }

    return json({
      ok: true,
      status: updated.status,
      durationSeconds,
    });
  } catch (error) {
    return fail(
      error instanceof Error ? error.message : 'Call control failed',
      401,
      'unauthorized',
    );
  }
});
