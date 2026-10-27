# Database tests

Run against a local Supabase stack:

```sh
supabase start
supabase test db
```

`001_core.test.sql` checks the initial RLS/trigger/function surface. The phase 5
migration should be applied before testing wallet policies. Add tests for every
new RLS policy and RPC, including negative cases (blocked sends, non-admin group
broadcasts, cross-user ledger reads and idempotency replays). Tests are written
as transaction-scoped pgTAP files so they can run in CI without leaving state.
