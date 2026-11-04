BEGIN;
SELECT plan(35);

SELECT has_table('public', 'staff_roles', 'staff roles exist');
SELECT has_table('public', 'tickets', 'support tickets exist');
SELECT has_table('public', 'ticket_messages', 'support messages exist');
SELECT has_table('public', 'announcements', 'announcements exist');
SELECT has_table('public', 'transactions', 'finance uses wallet transactions');

SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.staff_roles'::regclass), 'staff_roles has RLS');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.tickets'::regclass), 'tickets has RLS');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.ticket_messages'::regclass), 'ticket_messages has RLS');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.announcements'::regclass), 'announcements has RLS');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.audit_log'::regclass), 'audit_log remains protected');

SELECT has_function('public', 'has_role', ARRAY['text'], 'role checks are server-side');
SELECT has_function('public', 'has_permission', ARRAY['text'], 'permissions are server-side');
SELECT has_function('public', 'is_staff', ARRAY[]::text[], 'staff access check exists');
SELECT has_function('public', 'admin_review_transaction', ARRAY['uuid', 'boolean'], 'finance review uses a guarded RPC');
SELECT has_function('public', 'create_support_ticket', ARRAY['text', 'text'], 'ticket creation is atomic');
SELECT has_function('public', 'reply_support_ticket', ARRAY['uuid', 'text'], 'ticket replies are ownership checked');

SELECT has_column('public', 'transactions', 'created_by', 'transactions record their actor');
SELECT has_column('public', 'reports', 'staff_reply', 'reports can carry staff replies');
SELECT has_column('public', 'tickets', 'assigned_to', 'tickets track assignment');
SELECT has_trigger('public', 'transactions', 'set_transaction_actor', 'transaction actor is enforced');

SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'staff_roles' AND policyname = 'staff_roles_read'), 'staff role reads are permission gated');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tickets' AND policyname = 'tickets_user_or_staff_read'), 'ticket reads are owner or staff only');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tickets' AND policyname = 'tickets_user_create'), 'users can create their own tickets');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'ticket_messages' AND policyname = 'ticket_messages_read'), 'ticket threads are owner or staff only');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'announcements' AND policyname = 'announcements_public_read'), 'announcements are audience filtered');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'audit_log' AND policyname = 'audit_log_staff_read'), 'audit log reads are staff gated');

SELECT ok(NOT has_table_privilege('authenticated', 'public.transactions', 'INSERT'), 'users cannot create financial transactions');
SELECT ok(NOT has_table_privilege('authenticated', 'public.transactions', 'UPDATE'), 'users cannot change transaction status');
SELECT ok(NOT has_table_privilege('authenticated', 'public.wallets', 'INSERT'), 'users cannot create wallets directly');
SELECT ok(NOT has_table_privilege('authenticated', 'public.wallets', 'UPDATE'), 'users cannot change wallet status');
SELECT ok(NOT has_table_privilege('authenticated', 'public.ledger_entries', 'INSERT'), 'users cannot create ledger entries');
SELECT ok(NOT has_table_privilege('authenticated', 'public.staff_roles', 'INSERT'), 'users cannot assign staff roles directly');

SELECT ok(has_function_privilege('authenticated', 'public.is_staff()', 'EXECUTE'), 'authenticated users can check their own staff status');
SELECT ok(has_function_privilege('authenticated', 'public.admin_review_transaction(uuid,boolean)', 'EXECUTE'), 'finance review RPC verifies permission internally');
SELECT ok(NOT has_function_privilege('anon', 'public.admin_review_transaction(uuid,boolean)', 'EXECUTE'), 'anonymous users cannot review transactions');

SELECT * FROM finish();
ROLLBACK;
