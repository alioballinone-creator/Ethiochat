import { fail, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = { confirm?: string };

const CHUNK = 100;

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const body = await readJson<Body>(req);
    if (body.confirm !== 'DELETE') {
      return fail(
        'Type DELETE to confirm permanent account deletion',
        400,
        'confirmation_required',
      );
    }

    const admin = adminClient();

    // Remove media/avatars through the Storage API so the backing objects are
    // deleted as well as their metadata.
    const { data: objects, error: objectError } = await admin.rpc(
      'user_storage_object_paths',
      { p_user_id: user.id },
    );
    if (objectError) {
      return fail(
        `Could not enumerate account media: ${objectError.message}`,
        500,
        'storage_cleanup_failed',
      );
    }
    const byBucket = new Map<string, string[]>();
    for (const object of objects ?? []) {
      const bucket = String(object.bucket_id);
      const names = byBucket.get(bucket) ?? [];
      names.push(String(object.name));
      byBucket.set(bucket, names);
    }
    for (const [bucket, names] of byBucket) {
      for (let index = 0; index < names.length; index += CHUNK) {
        const chunk = names.slice(index, index + CHUNK);
        const { error: removeError } = await admin.storage
          .from(bucket)
          .remove(chunk);
        if (removeError) {
          return fail(
            `Could not delete account media from ${bucket}: ${removeError.message}`,
            500,
            'storage_cleanup_failed',
          );
        }
      }
    }

    // Direct conversations cannot remain meaningful when one participant no
    // longer exists. Group membership is removed by the auth-user cascade.
    const { data: memberships, error: membershipError } = await admin
      .from('conversation_members')
      .select('conversation_id')
      .eq('user_id', user.id);
    if (membershipError) {
      return fail(membershipError.message, 500);
    }
    const conversationIds = (memberships ?? []).map((row) =>
      String(row.conversation_id),
    );
    if (conversationIds.length > 0) {
      const { data: directConversations, error: conversationError } =
        await admin
          .from('conversations')
          .select('id')
          .in('id', conversationIds)
          .eq('type', 'direct');
      if (conversationError) {
        return fail(conversationError.message, 500);
      }
      const directIds = (directConversations ?? []).map((row) =>
        String(row.id),
      );
      if (directIds.length > 0) {
        const { error: deleteConversationError } = await admin
          .from('conversations')
          .delete()
          .in('id', directIds);
        if (deleteConversationError) {
          return fail(
            `Could not remove direct conversations: ${deleteConversationError.message}`,
            500,
          );
        }
      }
    }

    await admin.from('audit_log').insert({
      actor_id: user.id,
      action: 'account.deleted',
      target_type: 'account',
      target_id: user.id,
      metadata: { source: 'delete-account-function' },
    });

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) {
      return fail(
        `Account data was removed but the auth user could not be deleted: ${deleteError.message}`,
        500,
        'auth_delete_failed',
      );
    }

    return json({
      ok: true,
      deletedAt: new Date().toISOString(),
      mediaObjectsRemoved: objects?.length ?? 0,
    });
  } catch (error) {
    return fail(
      error instanceof Error ? error.message : 'Account deletion failed',
      401,
      'unauthorized',
    );
  }
});
