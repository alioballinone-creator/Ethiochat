import { createClient, type SupabaseClient, type User } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { env } from './http.ts';

export function adminClient(): SupabaseClient {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function userClient(req: Request): SupabaseClient {
  const authorization = req.headers.get('Authorization');
  if (!authorization) throw new Error('Missing Authorization header');
  return createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(req: Request): Promise<{ client: SupabaseClient; user: User; token: string }> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '').trim();
  if (!token) throw new Error('Missing bearer token');
  const client = userClient(req);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new Error('Invalid session');
  return { client, user: data.user, token };
}

export async function verifyWalletPin(
  client: SupabaseClient,
  pin: string,
): Promise<boolean> {
  const { data, error } = await client.rpc('wallet_verify_pin', { p_pin: pin });
  if (error) throw new Error(error.message);
  return data === true;
}
