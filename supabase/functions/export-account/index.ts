import { fail, json, preflight } from '../_shared/http.ts';
import { adminClient, requireUser } from '../_shared/supabase.ts';

const PAGE = 1000;
const MAX_ROWS_PER_TABLE = 50000;

type PageFactory = (
  from: number,
  to: number,
) => PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>;

async function exportRows(
  label: string,
  factory: PageFactory,
  partial: string[],
): Promise<unknown[]> {
  const rows: unknown[] = [];
  for (let from = 0; from < MAX_ROWS_PER_TABLE; from += PAGE) {
    const to = from + PAGE - 1;
    const { data, error } = await factory(from, to);
    if (error) throw new Error(`${label}: ${error.message}`);
    const page = data ?? [];
    rows.push(...page);
    if (page.length < PAGE) return rows;
  }
  partial.push(label);
  return rows;
}

Deno.serve(async (req) => {
  const early = preflight(req);
  if (early) return early;

  try {
    const { user } = await requireUser(req);
    const admin = adminClient();
    const partial: string[] = [];

    const profile = await admin
      .from('profiles')
      .select(
        'id,ethio_id,display_name,avatar_url,bio,language,last_seen_at,privacy,created_at,updated_at',
      )
      .eq('id', user.id)
      .maybeSingle();
    if (profile.error) throw new Error(profile.error.message);

    const memberships = await exportRows(
      'conversation_members',
      (from, to) =>
        admin
          .from('conversation_members')
          .select('*')
          .eq('user_id', user.id)
          .range(from, to),
      partial,
    );
    const conversationIds = memberships
      .map((row) => String((row as Record<string, unknown>).conversation_id))
      .filter(Boolean);
    const conversations: unknown[] = [];
    for (let index = 0; index < conversationIds.length; index += 100) {
      const chunk = conversationIds.slice(index, index + 100);
      const { data, error } = await admin
        .from('conversations')
        .select('*')
        .in('id', chunk);
      if (error) throw new Error(`conversations: ${error.message}`);
      conversations.push(...(data ?? []));
    }

    const calls = await exportRows(
      'calls',
      (from, to) =>
        admin
          .from('calls')
          .select('*')
          .or(`caller_id.eq.${user.id},callee_id.eq.${user.id}`)
          .order('created_at', { ascending: true })
          .range(from, to),
      partial,
    );

    const [
      messages,
      receipts,
      contacts,
      blocks,
      devices,
      reports,
      moments,
      momentLikes,
      momentComments,
      channelSubscriptions,
      officialAccountSubscriptions,
      officialAccountBookmarks,
      miniPrograms,
      wallets,
      transactions,
      ledgerEntries,
      redpackets,
      redpacketClaims,
      kyc,
    ] = await Promise.all([
      exportRows(
        'messages',
        (from, to) =>
          admin
            .from('messages')
            .select('*')
            .eq('sender_id', user.id)
            .order('created_at', { ascending: true })
            .range(from, to),
        partial,
      ),
      exportRows(
        'message_receipts',
        (from, to) =>
          admin
            .from('message_receipts')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'contacts',
        (from, to) =>
          admin
            .from('contacts')
            .select('*')
            .eq('owner_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'blocks',
        (from, to) =>
          admin
            .from('blocks')
            .select('*')
            .eq('owner_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'devices',
        (from, to) =>
          admin
            .from('devices')
            .select(
              'id,platform,last_active,created_at',
            )
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'reports',
        (from, to) =>
          admin
            .from('reports')
            .select('*')
            .eq('reporter_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'moments',
        (from, to) =>
          admin
            .from('moments')
            .select('*')
            .eq('author_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'moment_likes',
        (from, to) =>
          admin
            .from('moment_likes')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'moment_comments',
        (from, to) =>
          admin
            .from('moment_comments')
            .select('*')
            .eq('author_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'channel_subscriptions',
        (from, to) =>
          admin
            .from('channel_subscriptions')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'oa_subscriptions',
        (from, to) =>
          admin
            .from('oa_subscriptions')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'oa_bookmarks',
        (from, to) =>
          admin
            .from('oa_bookmarks')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'mini_programs',
        (from, to) =>
          admin
            .from('mini_programs')
            .select('*')
            .eq('publisher_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'wallets',
        (from, to) =>
          admin
            .from('wallets')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'transactions',
        (from, to) =>
          admin
            .from('transactions')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'ledger_entries',
        (from, to) =>
          admin
            .from('ledger_entries')
            .select('*')
            .eq('account', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'redpackets',
        (from, to) =>
          admin
            .from('redpackets')
            .select('*')
            .eq('sender_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'redpacket_claims',
        (from, to) =>
          admin
            .from('redpacket_claims')
            .select('*')
            .eq('claimer_id', user.id)
            .range(from, to),
        partial,
      ),
      exportRows(
        'kyc',
        (from, to) =>
          admin
            .from('kyc')
            .select('*')
            .eq('user_id', user.id)
            .range(from, to),
        partial,
      ),
    ]);

    return json({
      formatVersion: 1,
      exportedAt: new Date().toISOString(),
      userId: user.id,
      partial,
      account: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        createdAt: user.created_at,
        lastSignInAt: user.last_sign_in_at,
      },
      profile: profile.data,
      conversations,
      conversationMemberships: memberships,
      messages,
      messageReceipts: receipts,
      calls,
      contacts,
      blocks,
      devices,
      reports,
      moments,
      momentLikes,
      momentComments,
      channelSubscriptions,
      officialAccountSubscriptions,
      officialAccountBookmarks,
      miniPrograms,
      wallet: {
        accounts: wallets,
        transactions,
        ledgerEntries,
        redpackets,
        redpacketClaims,
        kyc,
      },
    });
  } catch (error) {
    return fail(
      error instanceof Error ? error.message : 'Account export failed',
      500,
      'export_failed',
    );
  }
});
