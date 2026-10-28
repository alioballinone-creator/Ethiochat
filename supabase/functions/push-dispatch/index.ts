import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.9.6';
import { fail, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient } from '../_shared/supabase.ts';

type WebhookBody = {
  type?: string;
  table?: string;
  schema?: string;
  record?: Record<string, unknown>;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type Device = {
  fcm_token: string;
  platform: string | null;
};

type Conversation = {
  id: string;
  type: string;
  title: string | null;
};

type Member = {
  user_id: string;
  muted_until: string | null;
};

const tokenUrl = 'https://oauth2.googleapis.com/token';
const fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  const provided = req.headers.get('x-webhook-secret');
  if (!webhookSecret) {
    return fail('Push dispatch is not configured', 503, 'not_configured');
  }
  if (!provided || provided !== webhookSecret) {
    return fail('Unauthorized webhook', 401, 'unauthorized');
  }

  try {
    const body = await readJson<WebhookBody>(req);
    if (body.schema !== 'public' || body.type !== 'INSERT' || !body.record) {
      return json({ skipped: 'unsupported_event' });
    }

    const admin = adminClient();
    if (body.table === 'messages') {
      const delivered = await dispatchMessage(admin, body.record);
      return json({ delivered });
    }
    if (body.table === 'calls') {
      const delivered = await dispatchCall(admin, body.record);
      return json({ delivered });
    }
    return json({ skipped: 'unsupported_table' });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Push dispatch failed';
    const status = /Missing FCM_|Missing SUPABASE/.test(message) ? 503 : 400;
    return fail(message, status, status === 503 ? 'not_configured' : 'bad_request');
  }
});

async function dispatchMessage(
  admin: ReturnType<typeof adminClient>,
  record: Record<string, unknown>,
): Promise<number> {
  if (record.deleted_at) return 0;
  if (record.type === 'system') return 0;
  const conversationId = String(record.conversation_id ?? '');
  const senderId = String(record.sender_id ?? '');
  const messageId = String(record.id ?? '');
  if (!conversationId || !senderId || !messageId) return 0;

  const [{ data: conversation, error: conversationError }, { data: members, error: membersError }] =
    await Promise.all([
      admin
        .from('conversations')
        .select('id,type,title')
        .eq('id', conversationId)
        .maybeSingle(),
      admin
        .from('conversation_members')
        .select('user_id,muted_until')
        .eq('conversation_id', conversationId)
        .is('left_at', null),
    ]);
  if (conversationError) throw new Error(conversationError.message);
  if (membersError) throw new Error(membersError.message);
  if (!conversation) return 0;

  const now = Date.now();
  const recipients = ((members ?? []) as Member[])
    .filter((member) => member.user_id !== senderId)
    .filter((member) => !member.muted_until || Date.parse(member.muted_until) <= now)
    .map((member) => member.user_id);
  if (recipients.length === 0) return 0;

  const [{ data: sender }, { data: devices, error: devicesError }] = await Promise.all([
    admin.from('profiles').select('display_name').eq('id', senderId).maybeSingle(),
    admin
      .from('devices')
      .select('fcm_token,platform')
      .in('user_id', recipients)
      .not('fcm_token', 'is', null),
  ]);
  if (devicesError) throw new Error(devicesError.message);

  const conv = conversation as Conversation;
  const senderName = String(sender?.display_name ?? 'EthioChat');
  const title = conv.type === 'group'
    ? (conv.title ?? 'Group chat')
    : senderName;
  const body = messagePreview(record);
  const data = {
    type: 'message',
    conversation_id: conversationId,
    message_id: messageId,
    sender_id: senderId,
    title,
    body,
  };
  return sendToDevices(
    (devices ?? []) as Device[],
    {
      title,
      body,
      data,
    },
    false,
  );
}

async function dispatchCall(
  admin: ReturnType<typeof adminClient>,
  record: Record<string, unknown>,
): Promise<number> {
  const callId = String(record.id ?? '');
  const callerId = String(record.caller_id ?? '');
  const conversationId = String(record.conversation_id ?? '');
  const type = record.type === 'video' ? 'video' : 'voice';
  if (!callId || !callerId || !conversationId) return 0;

  const recipients = new Set<string>();
  if (record.callee_id) recipients.add(String(record.callee_id));
  if (recipients.size === 0) {
    const { data: members, error } = await admin
      .from('conversation_members')
      .select('user_id,muted_until')
      .eq('conversation_id', conversationId)
      .is('left_at', null);
    if (error) throw new Error(error.message);
    const now = Date.now();
    for (const member of (members ?? []) as Member[]) {
      if (member.user_id === callerId) continue;
      if (member.muted_until && Date.parse(member.muted_until) > now) continue;
      recipients.add(member.user_id);
    }
  }
  if (recipients.size === 0) return 0;

  const [{ data: caller }, { data: devices, error: devicesError }] = await Promise.all([
    admin.from('profiles').select('display_name').eq('id', callerId).maybeSingle(),
    admin
      .from('devices')
      .select('fcm_token,platform')
      .in('user_id', [...recipients])
      .not('fcm_token', 'is', null),
  ]);
  if (devicesError) throw new Error(devicesError.message);

  const callerName = String(caller?.display_name ?? 'EthioChat');
  const title = `Incoming ${type} call`;
  const data = {
    type: 'incoming_call',
    call_id: callId,
    conversation_id: conversationId,
    video: String(type === 'video'),
    title,
    body: `${callerName} is calling`,
  };
  return sendToDevices(
    (devices ?? []) as Device[],
    {
      title,
      body: `${callerName} is calling`,
      data,
    },
    true,
  );
}

function messagePreview(record: Record<string, unknown>): string {
  if (record.type === 'text' && typeof record.body === 'string') {
    const body = record.body.trim();
    return body.length > 140 ? `${body.slice(0, 137)}…` : body;
  }
  return switchType(String(record.type ?? ''));
}

function switchType(type: string): string {
  switch (type) {
    case 'image':
      return 'Photo';
    case 'voice':
      return 'Voice message';
    case 'video':
      return 'Video';
    case 'file':
      return 'Document';
    case 'location':
      return 'Location';
    case 'payment':
      return 'Payment';
    case 'redpacket':
      return 'Red packet';
    default:
      return 'New message';
  }
}

async function sendToDevices(
  devices: Device[],
  content: {
    title: string;
    body: string;
    data: Record<string, string>;
  },
  isCall: boolean,
): Promise<number> {
  const uniqueTokens = [...new Set(
    devices.map((device) => device.fcm_token).filter((token) => !!token),
  )];
  if (uniqueTokens.length === 0) return 0;

  const serviceAccount = serviceAccountFromEnv();
  const accessToken = await firebaseAccessToken(serviceAccount);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  let delivered = 0;
  for (const token of uniqueTokens) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: content.title, body: content.body },
          data: content.data,
          android: {
            priority: isCall ? 'HIGH' : 'HIGH',
            notification: {
              channel_id: isCall ? 'ethiochat_calls' : 'ethiochat_messages',
              sound: 'default',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                sound: 'default',
                'interruption-level': isCall ? 'time-sensitive' : 'active',
              },
            },
          },
        },
      }),
    });
    if (response.ok) delivered++;
  }
  return delivered;
}

function serviceAccountFromEnv(): ServiceAccount {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Missing FCM_SERVICE_ACCOUNT_JSON');
  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(raw) as ServiceAccount;
  } catch {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON is not valid JSON');
  }
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error('FCM service account is incomplete');
  }
  return parsed;
}

async function firebaseAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({ scope: fcmScope })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(tokenUrl)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(await importPKCS8(account.private_key.replace(/\\n/g, '\n'), 'RS256'));

  const response = await fetch(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Firebase OAuth failed with ${response.status}`);
  }
  const payload = await response.json() as { access_token?: string };
  if (!payload.access_token) throw new Error('Firebase OAuth returned no token');
  return payload.access_token;
}
