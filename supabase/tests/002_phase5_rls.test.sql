begin;
select plan(22);

-- Phase 5 application tables exist and are protected.
select has_table('public', 'reports', 'reports table exists');
select has_table('public', 'blocks', 'blocks table exists');
select has_table('public', 'audit_log', 'audit_log table exists');
select has_table('public', 'feature_flags', 'feature_flags table exists');
select ok((select relrowsecurity from pg_class where relname = 'audit_log'),
  'audit_log has RLS');
select ok((select relrowsecurity from pg_class where relname = 'ledger_entries'),
  'ledger_entries has RLS');

-- RPC surface.
select has_function('public', 'create_direct_conversation', ARRAY['uuid'],
  'create_direct_conversation exists');
select has_function('public', 'send_message',
  ARRAY['uuid', 'uuid', 'text', 'text', 'jsonb', 'uuid'],
  'send_message exists');
select has_function('public', 'search_messages', ARRAY['text', 'integer'],
  'search_messages exists');
select has_function('public', 'wallet_set_pin', ARRAY['text'],
  'wallet_set_pin exists');

-- Critical policies were installed.
select ok(exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'messages'
      and policyname = 'messages_no_blocked_direct'
  ), 'direct messages reject blocked participants');
select ok(exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'messages'
      and policyname = 'messages_group_admin_only'
  ), 'group broadcasts are admin-only');
select ok(exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'moments'
      and policyname = 'moments_read'
  ), 'moments have a read policy');
select ok(exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reports'
      and policyname = 'reports_insert_own'
  ), 'users can submit reports');
select ok(exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'blocks'
      and policyname = 'blocks_own'
  ), 'users can manage only their own blocks');

-- Ledger grants: read-only for users, no mutation.
select ok(has_table_privilege('authenticated', 'public.ledger_entries', 'SELECT'),
  'authenticated may read its ledger rows through RLS');
select ok(not has_table_privilege('authenticated', 'public.ledger_entries', 'INSERT'),
  'authenticated cannot insert ledger rows');
select ok(not has_table_privilege('authenticated', 'public.ledger_entries', 'UPDATE'),
  'authenticated cannot update ledger rows');
select ok(not has_table_privilege('authenticated', 'public.ledger_entries', 'DELETE'),
  'authenticated cannot delete ledger rows');

-- Money mutation RPCs are service-role only; PIN setup remains user-callable.
select ok(not has_function_privilege(
    'authenticated',
    'public.wallet_transfer(uuid,bigint,text,text,uuid)',
    'EXECUTE'
  ), 'wallet_transfer is not callable by clients');
select ok(has_function_privilege(
    'service_role',
    'public.wallet_transfer(uuid,bigint,text,text,uuid)',
    'EXECUTE'
  ), 'wallet_transfer is callable by the service role');
select ok(has_function_privilege(
    'authenticated', 'public.wallet_set_pin(text)', 'EXECUTE'
  ), 'users can set their wallet PIN');

select * from finish();
rollback;
