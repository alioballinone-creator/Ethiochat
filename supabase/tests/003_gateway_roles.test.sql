begin;
select plan(4);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'role'
  ),
  'profiles has a role column'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_role_check'
  ),
  'profiles.role only accepts user or admin'
);

select has_function('is_admin', 'server-side admin check exists');

select has_trigger(
  'profiles',
  'protect_profile_role',
  'clients cannot change their own role'
);

select * from finish();
rollback;
