begin;
select plan(10);

-- RLS enabled
select ok((select relrowsecurity from pg_class where relname='profiles'), 'profiles has RLS');
select ok((select relrowsecurity from pg_class where relname='messages'), 'messages has RLS');
select ok((select relrowsecurity from pg_class where relname='conversations'), 'conversations has RLS');
select ok((select relrowsecurity from pg_class where relname='conversation_members'), 'conversation_members has RLS');
select ok((select relrowsecurity from pg_class where relname='wallets'), 'wallets has RLS');
select ok((select relrowsecurity from pg_class where relname='ledger_entries'), 'ledger_entries has RLS');

-- seq trigger exists
select has_trigger('messages', 'trg_assign_message_seq', 'seq trigger exists');

-- functions exist
select has_function('assign_message_seq', 'assign_message_seq exists');
select has_function('is_conversation_member', 'is_conversation_member exists');

select * from finish();
rollback;
