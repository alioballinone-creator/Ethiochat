import { fail, json, preflight, readJson } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

type Body = { hashes?: unknown };

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const body = await readJson<Body>(req);
    if (!Array.isArray(body.hashes)) return fail('hashes must be an array');
    const hashes = [...new Set(body.hashes)]
      .filter((value): value is string => typeof value === 'string')
      .filter((value) => /^[0-9a-f]{64}$/i.test(value))
      .slice(0, 500);
    if (hashes.length === 0) return json({ matches: [] });

    const { data, error } = await adminClient()
      .from('profiles')
      .select('id,ethio_id,display_name,avatar_url,phone_hash')
      .in('phone_hash', hashes)
      .neq('id', user.id)
      .is('deleted_at', null)
      .limit(500);
    if (error) return fail(error.message, 500, 'lookup_failed');

    // Phone hashes are only used for matching and are never returned raw.
    return json({
      matches: (data ?? []).map((row) => ({
        id: row.id,
        ethioId: row.ethio_id,
        displayName: row.display_name,
        avatarUrl: row.avatar_url,
        phoneHash: row.phone_hash,
      })),
    });
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Discovery failed', 401, 'unauthorized');
  }
});
