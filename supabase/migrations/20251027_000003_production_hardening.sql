-- Production hardening: account deletion, storage retries, and server-only calls.
--
-- This migration is intentionally additive so it can be applied to projects
-- that already contain the earlier phase migrations.

BEGIN;

-- Calls are created and transitioned by authenticated Edge Functions only.
-- Direct client inserts previously allowed an attacker to manufacture rows for
-- arbitrary conversations and room names.
DROP POLICY IF EXISTS calls_insert ON public.calls;

-- Profile values are validated server-side as well as in the client.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_display_name_length;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_display_name_length
  CHECK (
    display_name IS NULL
    OR char_length(btrim(display_name)) BETWEEN 2 AND 50
  );

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_bio_length;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_bio_length
  CHECK (bio IS NULL OR char_length(bio) <= 160);

-- Keep account deletion referentially safe. A deleted auth user must not leave
-- rows that block deletion or silently transfer data to another account.
ALTER TABLE public.calls
  DROP CONSTRAINT IF EXISTS calls_conversation_id_fkey,
  ADD CONSTRAINT calls_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
    ON DELETE CASCADE;

ALTER TABLE public.calls
  DROP CONSTRAINT IF EXISTS calls_caller_id_fkey,
  ADD CONSTRAINT calls_caller_id_fkey
    FOREIGN KEY (caller_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.calls
  DROP CONSTRAINT IF EXISTS calls_callee_id_fkey,
  ADD CONSTRAINT calls_callee_id_fkey
    FOREIGN KEY (callee_id) REFERENCES auth.users(id)
    ON DELETE SET NULL;

ALTER TABLE public.conversations
  DROP CONSTRAINT IF EXISTS conversations_created_by_fkey,
  ADD CONSTRAINT conversations_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES auth.users(id)
    ON DELETE SET NULL;

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_reply_to_fkey,
  ADD CONSTRAINT messages_reply_to_fkey
    FOREIGN KEY (reply_to) REFERENCES public.messages(id)
    ON DELETE SET NULL;

ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_user_id_fkey,
  ADD CONSTRAINT transactions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_conversation_id_fkey,
  ADD CONSTRAINT transactions_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
    ON DELETE SET NULL;

ALTER TABLE public.redpackets
  DROP CONSTRAINT IF EXISTS redpackets_sender_id_fkey,
  ADD CONSTRAINT redpackets_sender_id_fkey
    FOREIGN KEY (sender_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.redpackets
  DROP CONSTRAINT IF EXISTS redpackets_conversation_id_fkey,
  ADD CONSTRAINT redpackets_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
    ON DELETE SET NULL;

ALTER TABLE public.redpacket_claims
  DROP CONSTRAINT IF EXISTS redpacket_claims_claimer_id_fkey,
  ADD CONSTRAINT redpacket_claims_claimer_id_fkey
    FOREIGN KEY (claimer_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.channels
  DROP CONSTRAINT IF EXISTS channels_owner_id_fkey,
  ADD CONSTRAINT channels_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.official_accounts
  DROP CONSTRAINT IF EXISTS official_accounts_owner_id_fkey,
  ADD CONSTRAINT official_accounts_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES auth.users(id)
    ON DELETE CASCADE;

ALTER TABLE public.mini_programs
  DROP CONSTRAINT IF EXISTS mini_programs_publisher_id_fkey,
  ADD CONSTRAINT mini_programs_publisher_id_fkey
    FOREIGN KEY (publisher_id) REFERENCES auth.users(id)
    ON DELETE SET NULL;

-- Media retries need UPDATE permission for the original uploader, and account
-- deletion/expired media needs a safe DELETE path.
DROP POLICY IF EXISTS media_update_member ON storage.objects;
CREATE POLICY media_update_member ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND owner_id = auth.uid()
    AND public.is_conversation_member(
      NULLIF(split_part(name, '/', 1), '')::uuid,
      auth.uid()
    )
  ) WITH CHECK (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND owner_id = auth.uid()
    AND public.is_conversation_member(
      NULLIF(split_part(name, '/', 1), '')::uuid,
      auth.uid()
    )
  );

DROP POLICY IF EXISTS media_delete_own ON storage.objects;
CREATE POLICY media_delete_own ON storage.objects
  FOR DELETE USING (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND owner_id = auth.uid()
  );

DROP POLICY IF EXISTS avatars_delete_own ON storage.objects;
CREATE POLICY avatars_delete_own ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Call invitations (incoming-call UI and push fallbacks) are delivered through
-- Realtime while RLS still restricts rows to participants.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'calls'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.calls';
    END IF;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_calls_callee_status
  ON public.calls (callee_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_calls_caller_status
  ON public.calls (caller_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status_created
  ON public.reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON public.messages (conversation_id, created_at DESC);

COMMIT;

-- Service-role-only helper used by the account-deletion Edge Function. It
-- returns object paths owned by a user so the Storage API can remove both
-- metadata and the underlying object bytes.
BEGIN;
CREATE OR REPLACE FUNCTION public.user_storage_object_paths(p_user_id UUID)
RETURNS TABLE (bucket_id TEXT, name TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = storage, public, pg_temp
AS $$
  SELECT o.bucket_id::text, o.name::text
  FROM storage.objects o
  WHERE o.owner_id = p_user_id;
$$;
REVOKE ALL ON FUNCTION public.user_storage_object_paths(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.user_storage_object_paths(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_storage_object_paths(UUID) TO service_role;
COMMIT;
