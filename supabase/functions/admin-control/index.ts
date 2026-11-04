import { fail, isUuid, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = {
  action?: string;
  id?: string;
  userId?: string;
  role?: string;
  enabled?: boolean;
  search?: string;
  table?: string;
  status?: string;
  reply?: string;
  title?: string;
  message?: string;
  email?: string;
  audience?: string;
  assignedTo?: string | null;
  decision?: 'approve' | 'reject';
  key?: string;
};

const permissions: Record<string, string> = {
  access: 'dashboard.read',
  dashboard: 'dashboard.read',
  'users.list': 'users.read',
  'users.activity': 'users.read',
  'users.set-status': 'users.manage',
  'users.set-role': 'staff.manage',
  'staff.list': 'staff.read',
  'staff.invite': 'staff.manage',
  'staff.remove': 'staff.manage',
  'content.list': 'content.read',
  'content.moderate': 'content.moderate',
  'reports.list': 'reports.read',
  'reports.update': 'reports.reply',
  'tickets.list': 'tickets.read',
  'tickets.update': 'tickets.manage',
  'tickets.reply': 'tickets.manage',
  'announcements.list': 'announcements.manage',
  'announcements.save': 'announcements.manage',
  'finance.list': 'finance.read',
  'finance.review': 'finance.review',
  'settings.list': 'settings.manage',
  'settings.update': 'settings.manage',
  'audit.list': 'audit.read',
};

const validStaffRoles = new Set([
  'owner', 'admin', 'moderator', 'support', 'finance', 'content',
]);
const validAudiences = new Set([
  'all', 'user', 'owner', 'admin', 'moderator', 'support', 'finance', 'content',
]);
const contentTables = new Set([
  'moments', 'messages', 'channel_posts', 'oa_posts', 'mini_programs',
]);

async function checkPermission(
  caller: Awaited<ReturnType<typeof requireUser>>['client'],
  permission: string,
): Promise<void> {
  const { data, error } = await caller.rpc('has_permission', {
    permission_name: permission,
  });
  if (error) throw new Error('Could not verify staff permission.');
  if (data !== true) throw new Response('Staff permission required.', { status: 403 });
}

async function isOwner(
  caller: Awaited<ReturnType<typeof requireUser>>['client'],
): Promise<boolean> {
  const { data, error } = await caller.rpc('has_permission', {
    permission_name: 'staff.owner',
  });
  if (error) throw new Error('Could not verify owner permission.');
  return data === true;
}

async function audit(
  admin: ReturnType<typeof adminClient>,
  actorId: string,
  action: string,
  targetType: string,
  targetId: string | null,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  const { error } = await admin.from('audit_log').insert({
    actor_id: actorId,
    action,
    target_type: targetType,
    target_id: targetId,
    metadata,
  });
  if (error) throw new Error('The action could not be written to the audit log.');
}

function boundedText(value: unknown, max: number): string {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { client: caller, user } = await requireUser(req);
    const body = await readJson<Body>(req);
    const action = body.action ?? '';
    const permission = permissions[action];
    if (!permission) return fail('Unknown admin action.');
    await checkPermission(caller, permission);
    const admin = adminClient();

    if (action === 'access') {
      const actions: string[] = ['dashboard'];
      for (const [name, permissionName] of Object.entries(permissions)) {
        if (name === 'access') continue;
        const { data, error } = await caller.rpc('has_permission', {
          permission_name: permissionName,
        });
        if (error) throw new Error('Staff permissions are unavailable.');
        if (data === true) actions.push(name);
      }
      const sectionActions = [
        'dashboard', 'users.list', 'staff.list', 'content.list', 'reports.list',
        'tickets.list', 'announcements.list', 'finance.list', 'settings.list',
        'audit.list',
      ];
      const sections = sectionActions.filter((name) => actions.includes(name));
      return json({ sections, actions });
    }

    if (action === 'dashboard') {
      const day = new Date();
      day.setUTCHours(0, 0, 0, 0);
      const since = day.toISOString();
      const [users, active, newUsers, messages, reports, transactions] = await Promise.all([
        admin.from('profiles').select('id', { count: 'exact', head: true }).is('deleted_at', null),
        admin.from('profiles').select('id', { count: 'exact', head: true })
          .is('deleted_at', null).gte('last_seen_at', new Date(Date.now() - 30 * 86400000).toISOString()),
        admin.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', since),
        admin.from('messages').select('id', { count: 'exact', head: true }).gte('created_at', since),
        admin.from('reports').select('id', { count: 'exact', head: true }).in('status', ['open', 'reviewing']),
        admin.from('transactions').select('id', { count: 'exact', head: true }),
      ]);
      for (const result of [users, active, newUsers, messages, reports, transactions]) {
        if (result.error) throw new Error('Dashboard data is unavailable.');
      }
      return json({
        users: users.count ?? 0,
        activeUsers: active.count ?? 0,
        newUsersToday: newUsers.count ?? 0,
        messagesToday: messages.count ?? 0,
        reportsOpen: reports.count ?? 0,
        transactions: transactions.count ?? 0,
      });
    }

    if (action === 'users.list') {
      const search = boundedText(body.search, 80).replace(/[,%()]/g, ' ');
      let query = admin.from('profiles')
        .select('id,display_name,ethio_id,avatar_url,role,created_at,last_seen_at,deleted_at')
        .order('created_at', { ascending: false }).limit(100);
      if (search) query = query.or(`display_name.ilike.%${search}%,ethio_id.ilike.%${search}%`);
      const { data: profiles, error } = await query;
      if (error) throw new Error('User list is unavailable.');
      const ids = (profiles ?? []).map((row) => String(row.id));
      const { data: roleRows, error: roleError } = ids.length
        ? await admin.from('staff_roles').select('user_id,role').in('user_id', ids)
        : { data: [], error: null };
      if (roleError) throw new Error('User roles are unavailable.');
      const authUsers = ids.length ? await admin.auth.admin.listUsers({ page: 1, perPage: 1000 }) : { data: { users: [] }, error: null };
      if (authUsers.error) throw new Error('User status data is unavailable.');
      const usersById = new Map(authUsers.data.users.map((item) => [item.id, item]));
      const rolesById = new Map((roleRows ?? []).map((row) => [String(row.user_id), row.role]));
      return json({ users: (profiles ?? []).map((profile) => ({
        ...profile,
        role: rolesById.get(String(profile.id)) ?? profile.role,
        email: usersById.get(String(profile.id))?.email ?? null,
        bannedUntil: usersById.get(String(profile.id))?.banned_until ?? null,
      })) });
    }

    if (action === 'users.activity') {
      if (!isUuid(body.userId)) return fail('A valid user id is required.');
      const userId = body.userId;
      const [transactions, reports, tickets, messages] = await Promise.all([
        admin.from('transactions').select('id,type,status,amount_minor,created_at').eq('user_id', userId).order('created_at', { ascending: false }).limit(30),
        admin.from('reports').select('id,target_type,status,reason,created_at').eq('reporter_id', userId).order('created_at', { ascending: false }).limit(30),
        admin.from('tickets').select('id,subject,status,created_at,updated_at').eq('user_id', userId).order('updated_at', { ascending: false }).limit(30),
        admin.from('messages').select('id,conversation_id,type,created_at').eq('sender_id', userId).order('created_at', { ascending: false }).limit(30),
      ]);
      for (const result of [transactions, reports, tickets, messages]) {
        if (result.error) throw new Error('User activity is unavailable.');
      }
      return json({ transactions: transactions.data, reports: reports.data, tickets: tickets.data, messages: messages.data });
    }

    if (action === 'users.set-status') {
      if (!isUuid(body.userId) || typeof body.enabled !== 'boolean') return fail('A user and status are required.');
      if (body.userId === user.id) return fail('You cannot disable your own account.');
      const { error } = await admin.auth.admin.updateUserById(body.userId, {
        ban_duration: body.enabled ? 'none' : '876000h',
      });
      if (error) throw new Error('The account status could not be changed.');
      await audit(admin, user.id, body.enabled ? 'user.enabled' : 'user.disabled', 'user', body.userId);
      return json({ ok: true });
    }

    if (action === 'users.set-role') {
      if (!isUuid(body.userId)) return fail('A valid user id is required.');
      const role = body.role ?? 'user';
      if (role !== 'user' && !validStaffRoles.has(role)) return fail('Invalid role.');
      if (role === 'owner' && !await isOwner(caller)) return fail('Only an owner can assign the owner role.', 403, 'forbidden');
      if (body.userId === user.id && role === 'user') return fail('You cannot remove your own staff role.');
      if (role === 'user') {
        const { error } = await admin.from('staff_roles').delete().eq('user_id', body.userId);
        if (error) throw new Error('The role could not be removed.');
        await admin.from('profiles').update({ role: 'user' }).eq('id', body.userId);
      } else {
        const { error } = await admin.from('staff_roles').upsert({
          user_id: body.userId, role, assigned_by: user.id, updated_at: new Date().toISOString(),
        });
        if (error) throw new Error('The role could not be assigned.');
        const { error: profileError } = await admin.from('profiles')
          .update({ role: role === 'admin' ? 'admin' : 'user' }).eq('id', body.userId);
        if (profileError) throw new Error('The compatibility role could not be synchronized.');
      }
      await audit(admin, user.id, 'user.role.changed', 'user', body.userId, { role });
      return json({ ok: true });
    }

    if (action === 'staff.list') {
      const { data: roles, error } = await admin.from('staff_roles')
        .select('user_id,role,assigned_by,created_at,updated_at').order('created_at', { ascending: false }).limit(500);
      if (error) throw new Error('Staff list is unavailable.');
      const ids = (roles ?? []).map((row) => String(row.user_id));
      const { data: profiles, error: profileError } = ids.length
        ? await admin.from('profiles').select('id,display_name,ethio_id,avatar_url').in('id', ids)
        : { data: [], error: null };
      if (profileError) throw new Error('Staff profile data is unavailable.');
      const byId = new Map((profiles ?? []).map((row) => [String(row.id), row]));
      return json({ staff: (roles ?? []).map((row) => ({ ...row, profile: byId.get(String(row.user_id)) ?? null })) });
    }

    if (action === 'staff.invite') {
      const email = boundedText(body.email, 254).toLowerCase();
      const role = body.role ?? '';
      if (!email.includes('@') || !validStaffRoles.has(role)) return fail('Enter a valid email and staff role.');
      if (role === 'owner' && !await isOwner(caller)) return fail('Only an owner can assign the owner role.', 403, 'forbidden');
      const { data, error } = await admin.auth.admin.inviteUserByEmail(email);
      if (error || !data.user) return fail('Staff invite failed. Confirm Supabase email delivery is configured.', 502, 'invite_failed');
      const { error: roleError } = await admin.from('staff_roles').upsert({
        user_id: data.user.id, role, assigned_by: user.id,
      });
      if (roleError) throw new Error('The invite was sent, but the staff role could not be assigned.');
      await admin.from('profiles').update({ role: role === 'admin' ? 'admin' : 'user' }).eq('id', data.user.id);
      await audit(admin, user.id, 'staff.invited', 'user', data.user.id, { role });
      return json({ ok: true, userId: data.user.id });
    }

    if (action === 'staff.remove') {
      if (!isUuid(body.userId) || body.userId === user.id) return fail('Choose another staff account.');
      const { data: target, error: targetError } = await admin.from('staff_roles')
        .select('role').eq('user_id', body.userId).maybeSingle();
      if (targetError || !target) return fail('Staff account not found.', 404);
      if (target.role === 'owner' && !await isOwner(caller)) return fail('Only an owner can remove an owner.', 403, 'forbidden');
      const { error } = await admin.from('staff_roles').delete().eq('user_id', body.userId);
      if (error) throw new Error('The staff role could not be removed.');
      await admin.from('profiles').update({ role: 'user' }).eq('id', body.userId);
      await audit(admin, user.id, 'staff.role.removed', 'user', body.userId, { role: target.role });
      return json({ ok: true });
    }

    if (action === 'content.list') {
      const table = body.table ?? 'moments';
      if (!contentTables.has(table)) return fail('Unsupported content type.');
      const { data, error } = await admin.from(table).select('*').order('created_at', { ascending: false }).limit(100);
      if (error) throw new Error('Content list is unavailable.');
      return json({ items: data ?? [] });
    }

    if (action === 'content.moderate') {
      const table = body.table ?? '';
      if (!contentTables.has(table) || !isUuid(body.id)) return fail('Invalid content target.');
      const decision = body.status;
      if (table === 'mini_programs') {
        if (!['approved', 'suspended', 'rejected'].includes(decision ?? '')) return fail('Invalid content action.');
        const { error } = await admin.from(table).update({ status: decision, updated_at: new Date().toISOString() }).eq('id', body.id);
        if (error) throw new Error('Content status could not be changed.');
      } else {
        if (!['approved', 'hidden', 'visible', 'deleted'].includes(decision ?? '')) return fail('Invalid content action.');
        const { error } = await admin.from(table).update({
          deleted_at: decision === 'hidden' || decision === 'deleted'
            ? new Date().toISOString()
            : null,
        }).eq('id', body.id);
        if (error) throw new Error('Content status could not be changed.');
      }
      await audit(admin, user.id, `content.${decision}`, table, body.id);
      return json({ ok: true });
    }

    if (action === 'reports.list') {
      const { data, error } = await admin.from('reports').select('*').order('created_at', { ascending: false }).limit(200);
      if (error) throw new Error('Report queue is unavailable.');
      return json({ reports: data ?? [] });
    }

    if (action === 'reports.update') {
      if (!isUuid(body.id) || !['open', 'reviewing', 'resolved', 'dismissed'].includes(body.status ?? '')) return fail('Invalid report update.');
      const { error } = await admin.from('reports').update({
        status: body.status,
        staff_reply: boundedText(body.reply, 3000) || null,
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq('id', body.id);
      if (error) throw new Error('Report could not be updated.');
      await audit(admin, user.id, 'report.updated', 'report', body.id, { status: body.status });
      return json({ ok: true });
    }

    if (action === 'tickets.list') {
      const { data, error } = await admin.from('tickets').select('*,ticket_messages(*)')
        .order('updated_at', { ascending: false }).limit(200);
      if (error) throw new Error('Support inbox is unavailable.');
      return json({ tickets: data ?? [] });
    }

    if (action === 'tickets.update') {
      if (!isUuid(body.id) || !['open', 'assigned', 'resolved'].includes(body.status ?? '')) return fail('Invalid ticket update.');
      const assignedTo = body.assignedTo === null ? null : (body.assignedTo ?? user.id);
      if (assignedTo !== null && !isUuid(assignedTo)) return fail('Invalid assignee.');
      const { error } = await admin.from('tickets').update({
        status: body.status, assigned_to: assignedTo, updated_at: new Date().toISOString(),
      }).eq('id', body.id);
      if (error) throw new Error('Ticket could not be updated.');
      await audit(admin, user.id, 'ticket.updated', 'ticket', body.id, { status: body.status, assigned_to: assignedTo });
      return json({ ok: true });
    }

    if (action === 'tickets.reply') {
      if (!isUuid(body.id)) return fail('Invalid ticket id.');
      const text = boundedText(body.reply, 5000);
      if (!text) return fail('Reply cannot be empty.');
      const { error } = await admin.from('ticket_messages').insert({ ticket_id: body.id, sender_id: user.id, body: text });
      if (error) throw new Error('Ticket reply could not be sent.');
      await admin.from('tickets').update({ status: 'assigned', assigned_to: user.id, updated_at: new Date().toISOString() }).eq('id', body.id);
      await audit(admin, user.id, 'ticket.replied', 'ticket', body.id);
      return json({ ok: true });
    }

    if (action === 'announcements.list') {
      const { data, error } = await admin.from('announcements').select('*').order('created_at', { ascending: false }).limit(200);
      if (error) throw new Error('Announcements are unavailable.');
      return json({ announcements: data ?? [] });
    }

    if (action === 'announcements.save') {
      const title = boundedText(body.title, 160);
      const message = boundedText(body.message, 5000);
      const audience = body.audience ?? 'all';
      const status = body.status ?? 'published';
      if (!title || !message || !validAudiences.has(audience) || !['draft', 'published', 'archived'].includes(status)) return fail('Enter a title, message, audience, and valid status.');
      const values = {
        title, message, audience, status, created_by: user.id,
        published_at: status === 'published' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      };
      const result = body.id && isUuid(body.id)
        ? await admin.from('announcements').update(values).eq('id', body.id).select('id').single()
        : await admin.from('announcements').insert(values).select('id').single();
      if (result.error) throw new Error('Announcement could not be saved.');
      await audit(admin, user.id, `announcement.${status}`, 'announcement', result.data.id, { audience });
      return json({ ok: true, id: result.data.id });
    }

    if (action === 'finance.list') {
      const status = body.status ?? 'all';
      let query = admin.from('transactions').select('id,user_id,created_by,type,status,amount_minor,fee_minor,provider,provider_ref,created_at,updated_at')
        .order('created_at', { ascending: false }).limit(500);
      if (status !== 'all') query = query.eq('status', status);
      const { data, error } = await query;
      if (error) throw new Error('Transaction list is unavailable.');
      const rows = data ?? [];
      const totals = rows.reduce((acc, row) => {
        const amount = Number(row.amount_minor ?? 0);
        const key = String(row.status ?? 'unknown');
        acc[key] = (acc[key] ?? 0) + amount;
        return acc;
      }, {} as Record<string, number>);
      return json({ transactions: rows, totals });
    }

    if (action === 'finance.review') {
      if (!isUuid(body.id) || !['approve', 'reject'].includes(body.decision ?? '')) return fail('Invalid transaction review.');
      const { error } = await caller.rpc('admin_review_transaction', {
        p_transaction_id: body.id,
        p_approve: body.decision === 'approve',
      });
      if (error) return fail(error.message, 400, 'review_failed');
      return json({ ok: true });
    }

    if (action === 'settings.list') {
      const { data, error } = await admin.from('feature_flags').select('key,enabled,description,rollout_percent,updated_at').order('key');
      if (error) throw new Error('App settings are unavailable.');
      return json({ flags: data ?? [] });
    }

    if (action === 'settings.update') {
      const key = boundedText(body.key, 80);
      if (!/^[a-z][a-z0-9_]*$/.test(key) || typeof body.enabled !== 'boolean') return fail('Invalid feature flag.');
      const { error } = await admin.from('feature_flags').upsert({
        key,
        enabled: body.enabled,
        rollout_percent: body.enabled ? 100 : 0,
        updated_at: new Date().toISOString(),
      });
      if (error) throw new Error('App setting could not be updated.');
      await audit(admin, user.id, 'settings.flag.updated', 'feature_flag', key, { enabled: body.enabled });
      return json({ ok: true });
    }

    if (action === 'audit.list') {
      const { data, error } = await admin.from('audit_log').select('*').order('created_at', { ascending: false }).limit(500);
      if (error) throw new Error('Audit log is unavailable.');
      return json({ entries: data ?? [] });
    }

    return fail('Unknown admin action.');
  } catch (error) {
    if (error instanceof Response) return fail(await error.text(), error.status, 'forbidden');
    return fail(error instanceof Error ? error.message : 'Admin action failed.', 400);
  }
});
