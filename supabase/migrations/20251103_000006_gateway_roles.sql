-- Gateway roles
--
-- Role data lives on public.profiles so the app can identify admins, while the
-- actual decision is made by the SECURITY DEFINER is_admin() RPC on the server.
-- Authenticated clients may read their own profile row (existing RLS policy)
-- but cannot promote themselves: protect_profile_role() rejects any client-side
-- role change. Admins are provisioned through the Supabase dashboard/SQL or a
-- service-role operation, never by release code.
--
-- To provision an admin: create the auth user in the Supabase dashboard, then
-- set public.profiles.role = 'admin' for that user. Test credentials belong in
-- the dashboard only and must never be committed to the repository.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_role_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_role_check
      CHECK (role IN ('user', 'admin'));
  END IF;
END;
$$;

-- Preserve existing server-managed admins from the legacy allowlist. This runs
-- before the guard trigger is installed.
UPDATE public.profiles p
SET role = 'admin'
FROM public.admin_users a
WHERE a.user_id = p.id
  AND p.role <> 'admin';

-- A client may create its own profile row, but only as a normal user. Admin
-- provisioning happens through the dashboard/service role, which bypasses RLS.
DROP POLICY IF EXISTS profiles_insert_self ON public.profiles;
CREATE POLICY profiles_insert_self ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid() AND role = 'user');

CREATE OR REPLACE FUNCTION public.protect_profile_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     AND coalesce(auth.role(), '') <> 'service_role'
     AND session_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'profiles.role is managed by the server'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_role ON public.profiles;
CREATE TRIGGER protect_profile_role
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_role();

-- Server-side role check used by the hidden gateway. The client calls
-- rpc('is_admin') with no arguments; the function can only ever inspect the
-- caller's own role.
DROP FUNCTION IF EXISTS public.is_admin(UUID);

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
      AND p.deleted_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
