import { SignJWT } from 'https://esm.sh/jose@5.9.6';
import { env, fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = {
  action?: 'start' | 'join';
  conversationId?: string;
  callId?: string;
  type?: 'voice' | 'video';
  video?: boolean;
};

type CallRow = {
  id: string;
  conversation_id: string;
  caller_id: string;
  callee_id: string | null;
  type: 'voice' | 'video';
  status: string;
  livekit_room: string | null;
  started_at: string | null;
};

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const body = await readJson<Body>(req);
    const admin = adminClient();

    let call: CallRow;

    if (body.action === 'start') {
      if (!isUuid(body.conversationId)) {
        return fail('conversationId must be a UUID');
      }
      const requestedType = body.type === 'video' || body.video ? 'video' : 'voice';

      const { data: conversation, error: conversationError } = await admin
        .from('conversations')
        .select('id,type,deleted_at')
        .eq('id', body.conversationId)
        .maybeSingle();
      if (conversationError) return fail(conversationError.message, 500);
      if (!conversation || conversation.deleted_at) {
        return fail('Conversation not found', 404, 'not_found');
      }
      if (conversation.type !== 'direct' && conversation.type !== 'group') {
        return fail('Calls are not available in this conversation', 400);
      }

      const { data: members, error: membersError } = await admin
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', body.conversationId)
        .is('left_at', null);
      if (membersError) return fail(membersError.message, 500);
      const memberIds = (members ?? []).map((row) => String(row.user_id));
      if (!memberIds.includes(user.id)) {
        return fail('You are not a member of this conversation', 403, 'forbidden');
      }
      const otherId = conversation.type === 'direct'
        ? memberIds.find((id) => id !== user.id) ?? null
        : null;
      if (conversation.type === 'direct' && !otherId) {
        return fail('The other participant is no longer available', 409);
      }
      if (otherId) {
        const { data: blockedByMe } = await admin
          .from('contacts')
          .select('owner_id')
          .eq('owner_id', user.id)
          .eq('contact_id', otherId)
          .eq('status', 'blocked')
          .maybeSingle();
        const { data: blockedMe } = await admin
          .from('contacts')
          .select('owner_id')
          .eq('owner_id', otherId)
          .eq('contact_id', user.id)
          .eq('status', 'blocked')
          .maybeSingle();
        if (blockedByMe || blockedMe) {
          return fail('Calling is unavailable for this contact', 403, 'blocked');
        }
      }

      const fiveMinutesAgo = new Date(Date.now() - 5 * 60_000).toISOString();
      const { data: existing } = await admin
        .from('calls')
        .select('id,conversation_id,caller_id,callee_id,type,status,livekit_room,started_at')
        .eq('conversation_id', body.conversationId)
        .eq('caller_id', user.id)
        .eq('type', requestedType)
        .eq('status', 'ringing')
        .gte('created_at', fiveMinutesAgo)
        .not('livekit_room', 'is', null)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (existing) {
        call = existing as CallRow;
      } else {
        const livekitRoom = `call_${crypto.randomUUID()}`;
        const { data: created, error: createError } = await admin
          .from('calls')
          .insert({
            conversation_id: body.conversationId,
            caller_id: user.id,
            callee_id: otherId,
            type: requestedType,
            status: 'ringing',
            livekit_room: livekitRoom,
          })
          .select('id,conversation_id,caller_id,callee_id,type,status,livekit_room,started_at')
          .single();
        if (createError || !created) {
          return fail(createError?.message ?? 'Could not create the call', 500);
        }
        call = created as CallRow;
      }
    } else if (body.action === 'join') {
      if (!isUuid(body.callId)) return fail('callId must be a UUID');
      const { data: found, error } = await admin
        .from('calls')
        .select('id,conversation_id,caller_id,callee_id,type,status,livekit_room,started_at')
        .eq('id', body.callId)
        .maybeSingle();
      if (error) return fail(error.message, 500);
      if (!found) return fail('Call not found', 404, 'not_found');
      call = found as CallRow;
      if (!call.livekit_room) return fail('Call has no media room', 409);
      if (!['ringing', 'accepted'].includes(call.status)) {
        return fail('This call is no longer active', 409, 'call_ended');
      }

      const { data: membership } = await admin
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', call.conversation_id)
        .eq('user_id', user.id)
        .is('left_at', null)
        .maybeSingle();
      if (!membership && call.caller_id !== user.id && call.callee_id !== user.id) {
        return fail('You are not invited to this call', 403, 'forbidden');
      }

      if (call.status === 'ringing' && call.caller_id !== user.id) {
        const startedAt = new Date().toISOString();
        const { data: accepted } = await admin
          .from('calls')
          .update({ status: 'accepted', started_at: call.started_at ?? startedAt })
          .eq('id', call.id)
          .eq('status', 'ringing')
          .select('id,conversation_id,caller_id,callee_id,type,status,livekit_room,started_at')
          .maybeSingle();
        if (accepted) call = accepted as CallRow;
      }
    } else {
      return fail('action must be start or join');
    }

    if (!call.livekit_room) return fail('Call has no media room', 409);

    await admin
      .from('call_participants')
      .upsert(
        {
          call_id: call.id,
          user_id: user.id,
          joined_at: new Date().toISOString(),
          left_at: null,
        },
        { onConflict: 'call_id,user_id' },
      );

    const { data: profile } = await admin
      .from('profiles')
      .select('display_name')
      .eq('id', user.id)
      .maybeSingle();

    const apiKey = env('LIVEKIT_API_KEY');
    const apiSecret = env('LIVEKIT_API_SECRET');
    const url = env('LIVEKIT_URL');
    const now = Math.floor(Date.now() / 1000);
    const identity = user.id;
    const token = await new SignJWT({
      name: String(profile?.display_name ?? 'EthioChat user'),
      video: {
        room: call.livekit_room,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        canPublishSources: ['camera', 'microphone'],
      },
    })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuer(apiKey)
      .setSubject(identity)
      .setIssuedAt(now)
      .setNotBefore(now - 5)
      .setExpirationTime('15m')
      .setJti(crypto.randomUUID())
      .sign(new TextEncoder().encode(apiSecret));

    return json({
      url,
      token,
      room: call.livekit_room,
      callId: call.id,
      identity,
      status: call.status,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Call request failed';
    const status = /Missing LIVEKIT|Missing SUPABASE/.test(message) ? 503 : 401;
    return fail(message, status, status === 503 ? 'not_configured' : 'unauthorized');
  }
});
