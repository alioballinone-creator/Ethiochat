-- Receipts, remote edit/delete enforcement, and the smallest admin primitive.
--
-- All functions are additive and safe to apply on top of the phase migrations.

BEGIN;

-- Read receipts: updating only last_read_seq made the read state invisible to
-- other devices and to senders. Materialise a receipt row for every inbound
-- message up to the requested sequence in the same transaction.
CREATE OR REPLACE FUNCTION public.mark_conversation_read(
  p_conversation UUID,
  p_seq BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_seq BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_conversation_member(p_conversation, v_uid) THEN
    RAISE EXCEPTION 'You are not in this conversation' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(MAX(seq), 0)
    INTO v_seq
    FROM public.messages
   WHERE conversation_id = p_conversation
     AND (p_seq IS NULL OR p_seq <= 0 OR seq <= p_seq);

  UPDATE public.conversation_members
     SET last_read_seq = GREATEST(COALESCE(last_read_seq, 0), v_seq)
   WHERE conversation_id = p_conversation
     AND user_id = v_uid;

  INSERT INTO public.message_receipts (message_id, user_id, delivered_at, read_at)
  SELECT m.id, v_uid, NOW(), NOW()
    FROM public.messages m
   WHERE m.conversation_id = p_conversation
     AND m.seq <= v_seq
     AND m.sender_id <> v_uid
     AND m.deleted_at IS NULL
  ON CONFLICT (message_id, user_id) DO UPDATE
    SET delivered_at = COALESCE(public.message_receipts.delivered_at, EXCLUDED.delivered_at),
        read_at = COALESCE(public.message_receipts.read_at, EXCLUDED.read_at);
END;
$$;
REVOKE ALL ON FUNCTION public.mark_conversation_read(UUID, BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(UUID, BIGINT) TO authenticated;

-- Edit/delete policy is enforced at the database boundary, not just in the
-- Flutter client. A sender may edit text for 15 minutes and delete for everyone
-- for 24 hours; immutable columns cannot be rewritten.
CREATE OR REPLACE FUNCTION public.guard_message_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.seq IS DISTINCT FROM OLD.seq
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.type IS DISTINCT FROM OLD.type
     OR NEW.reply_to IS DISTINCT FROM OLD.reply_to THEN
    RAISE EXCEPTION 'Message identity fields cannot be changed' USING ERRCODE = '22023';
  END IF;

  IF OLD.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Deleted messages cannot be changed' USING ERRCODE = '22023';
  END IF;

  IF NEW.deleted_at IS NOT NULL THEN
    IF auth.uid() IS DISTINCT FROM OLD.sender_id THEN
      RAISE EXCEPTION 'Only the sender can delete a message' USING ERRCODE = '42501';
    END IF;
    IF NOW() - OLD.created_at > INTERVAL '24 hours' THEN
      RAISE EXCEPTION 'Messages can only be deleted for everyone for 24 hours' USING ERRCODE = '22023';
    END IF;
    NEW.body := NULL;
    NEW.media := NULL;
    NEW.edited_at := OLD.edited_at;
    RETURN NEW;
  END IF;

  IF NEW.body IS DISTINCT FROM OLD.body OR NEW.media IS DISTINCT FROM OLD.media THEN
    IF auth.uid() IS DISTINCT FROM OLD.sender_id THEN
      RAISE EXCEPTION 'Only the sender can edit a message' USING ERRCODE = '42501';
    END IF;
    IF OLD.type <> 'text' THEN
      RAISE EXCEPTION 'Only text messages can be edited' USING ERRCODE = '22023';
    END IF;
    IF NOW() - OLD.created_at > INTERVAL '15 minutes' THEN
      RAISE EXCEPTION 'Messages can only be edited for 15 minutes' USING ERRCODE = '22023';
    END IF;
    NEW.edited_at := NOW();
  ELSE
    NEW.edited_at := OLD.edited_at;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_message_mutation ON public.messages;
CREATE TRIGGER trg_guard_message_mutation
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.guard_message_mutation();

-- Ensure receipts are delivered in realtime when the publication exists.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'message_receipts'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.message_receipts';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'conversation_members'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members';
    END IF;
  END IF;
END
$$;

-- FCM registration is per (user, token). Keep a partial unique index so token
-- refresh can use an idempotent upsert without blocking tokenless devices.
DELETE FROM public.devices a
USING public.devices b
WHERE a.ctid < b.ctid
  AND a.user_id = b.user_id
  AND a.fcm_token IS NOT NULL
  AND a.fcm_token = b.fcm_token;

CREATE UNIQUE INDEX IF NOT EXISTS devices_user_fcm_token_uidx
  ON public.devices (user_id, fcm_token)
  WHERE fcm_token IS NOT NULL AND btrim(fcm_token) <> '';

CREATE INDEX IF NOT EXISTS idx_receipts_message ON public.message_receipts (message_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_active ON public.devices (user_id, last_active DESC);

-- Admin identities are a separate table so a compromised profile update cannot
-- grant moderation privileges. There are deliberately no client policies.
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_users FROM PUBLIC;
REVOKE ALL ON public.admin_users FROM anon, authenticated;
GRANT ALL ON public.admin_users TO service_role;

COMMIT;
