-- Phase B: allow 'post' as reports.target_type (idempotent). Do not change existing rows.
DO $$
DECLARE c text;
BEGIN
  SELECT con.conname INTO c
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public' AND rel.relname = 'reports' AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) ILIKE '%target_type%';
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.reports DROP CONSTRAINT %I', c);
  END IF;
END $$;
ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports
  ADD CONSTRAINT reports_target_type_check
  CHECK (target_type IN ('account','message','group','channel','moment','problem','post'));
