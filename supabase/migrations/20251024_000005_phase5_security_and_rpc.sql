-- Phase 5: production hardening, group settings, discovery subscriptions,
-- reports, search, and the wallet RPC surface.
--
-- All functions are idempotent where practical. Security-definer functions
-- pin search_path and check auth.uid() explicitly.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE OR REPLACE FUNCTION public.assign_message_seq()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  next_seq BIGINT;
BEGIN
  UPDATE public.conversations
     SET seq_counter = seq_counter + 1,
         updated_at  = NOW()
   WHERE id = NEW.conversation_id
   RETURNING seq_counter INTO next_seq;
  NEW.seq := next_seq;
  NEW.created_at := COALESCE(NEW.created_at, NOW());
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_conversation_member(cid UUID, uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = cid AND user_id = uid AND left_at IS NULL
  );
$$;

-- ---------------------------------------------------------------------------
-- Profile bootstrap and lookup
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, ethio_id, display_name, phone_hash)
  VALUES (
    NEW.id,
    'ET' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'EthioChat user'),
    encode(digest(COALESCE(NEW.phone, NEW.email, NEW.id::text), 'sha256'), 'hex')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.find_profile(p_ethio_id TEXT)
RETURNS TABLE (id UUID, ethio_id TEXT, display_name TEXT, avatar_url TEXT, bio TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p.id, p.ethio_id, p.display_name, p.avatar_url, p.bio
  FROM public.profiles p
  WHERE auth.uid() IS NOT NULL
    AND upper(p.ethio_id) = upper(trim(p_ethio_id))
    AND p.deleted_at IS NULL
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.find_profile(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_profile(TEXT) TO authenticated;

-- Profiles are visible to accepted contacts and people sharing a chat.
DROP POLICY IF EXISTS profiles_select_contacts ON public.profiles;
CREATE POLICY profiles_select_contacts ON public.profiles
  FOR SELECT USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.contacts c
      WHERE c.status = 'accepted'
        AND (
          (c.owner_id = auth.uid() AND c.contact_id = profiles.id)
          OR (c.contact_id = auth.uid() AND c.owner_id = profiles.id)
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.conversation_members me
      JOIN public.conversation_members them
        ON them.conversation_id = me.conversation_id
      WHERE me.user_id = auth.uid()
        AND them.user_id = profiles.id
        AND me.left_at IS NULL
        AND them.left_at IS NULL
    )
  );

-- ---------------------------------------------------------------------------
-- Conversation creation and group controls
-- ---------------------------------------------------------------------------
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS only_admins_can_send BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS approve_members BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS disappearing_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS pinned_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_conversations_last_message
  ON public.conversations (last_message_at DESC NULLS LAST);

DROP POLICY IF EXISTS conversations_insert_creator ON public.conversations;
CREATE POLICY conversations_insert_creator ON public.conversations
  FOR INSERT WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS members_delete_self_or_admin ON public.conversation_members;
CREATE POLICY members_delete_self_or_admin ON public.conversation_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_members.conversation_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.left_at IS NULL
    )
  );

CREATE OR REPLACE FUNCTION public.is_blocked_between(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contacts c
    WHERE c.status = 'blocked'
      AND (
        (c.owner_id = p_a AND c.contact_id = p_b)
        OR (c.owner_id = p_b AND c.contact_id = p_a)
      )
  );
$$;
REVOKE ALL ON FUNCTION public.is_blocked_between(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_blocked_between(UUID, UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_direct_conversation(p_other UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_id UUID;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_other IS NULL OR p_other = v_me THEN
    RAISE EXCEPTION 'Choose another person' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_other AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0002';
  END IF;
  IF public.is_blocked_between(v_me, p_other) THEN
    RAISE EXCEPTION 'You cannot start a chat with this person' USING ERRCODE = '42501';
  END IF;

  SELECT c.id INTO v_id
  FROM public.conversations c
  WHERE c.type = 'direct' AND c.deleted_at IS NULL
    AND EXISTS (SELECT 1 FROM public.conversation_members m WHERE m.conversation_id = c.id AND m.user_id = v_me AND m.left_at IS NULL)
    AND EXISTS (SELECT 1 FROM public.conversation_members m WHERE m.conversation_id = c.id AND m.user_id = p_other AND m.left_at IS NULL)
  ORDER BY c.created_at
  LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.conversations (type, created_by)
    VALUES ('direct', v_me)
    RETURNING id INTO v_id;

    INSERT INTO public.conversation_members (conversation_id, user_id, role)
    VALUES (v_id, v_me, 'owner'), (v_id, p_other, 'member')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.create_direct_conversation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_direct_conversation(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_group_conversation(
  p_title TEXT,
  p_member_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_id UUID;
  v_member UUID;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF coalesce(trim(p_title), '') = '' THEN
    RAISE EXCEPTION 'Group name is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.conversations (type, title, created_by)
  VALUES ('group', trim(p_title), v_me)
  RETURNING id INTO v_id;

  INSERT INTO public.conversation_members (conversation_id, user_id, role)
  VALUES (v_id, v_me, 'owner');

  FOREACH v_member IN ARRAY coalesce(p_member_ids, ARRAY[]::UUID[]) LOOP
    IF v_member <> v_me AND EXISTS (SELECT 1 FROM public.profiles WHERE id = v_member) THEN
      INSERT INTO public.conversation_members (conversation_id, user_id, role)
      VALUES (v_id, v_member, 'member')
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.create_group_conversation(TEXT, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_group_conversation(TEXT, UUID[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_group_member_role(
  p_conversation UUID,
  p_member UUID,
  p_admin BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = p_conversation
      AND user_id = auth.uid()
      AND role IN ('owner', 'admin')
      AND left_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.conversation_members
  SET role = CASE WHEN p_admin THEN 'admin' ELSE 'member' END
  WHERE conversation_id = p_conversation
    AND user_id = p_member
    AND role <> 'owner';
END;
$$;
REVOKE ALL ON FUNCTION public.set_group_member_role(UUID, UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_group_member_role(UUID, UUID, BOOLEAN) TO authenticated;

-- Blocked people cannot post into a direct conversation. In groups, blocking a
-- person only affects their direct chat.
DROP POLICY IF EXISTS messages_no_blocked_direct ON public.messages;
CREATE POLICY messages_no_blocked_direct ON public.messages
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND c.type = 'direct'
        AND public.is_blocked_between(
          auth.uid(),
          (SELECT m.user_id FROM public.conversation_members m
           WHERE m.conversation_id = c.id AND m.user_id <> auth.uid() LIMIT 1)
        )
    )
  );

DROP POLICY IF EXISTS messages_group_admin_only ON public.messages;
CREATE POLICY messages_group_admin_only ON public.messages
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND c.type = 'group'
        AND c.only_admins_can_send
        AND NOT EXISTS (
          SELECT 1 FROM public.conversation_members m
          WHERE m.conversation_id = c.id
            AND m.user_id = auth.uid()
            AND m.role IN ('owner', 'admin')
            AND m.left_at IS NULL
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Messages, receipts and search
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_id = NEW.id,
      last_message_at = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_conversation_last_message ON public.messages;
CREATE TRIGGER trg_update_conversation_last_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_last_message();

CREATE OR REPLACE FUNCTION public.send_message(
  p_id UUID,
  p_conversation UUID,
  p_type TEXT,
  p_body TEXT DEFAULT NULL,
  p_media JSONB DEFAULT NULL,
  p_reply_to UUID DEFAULT NULL
)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.messages;
BEGIN
  IF NOT public.is_conversation_member(p_conversation, auth.uid()) THEN
    RAISE EXCEPTION 'You are not in this conversation' USING ERRCODE = '42501';
  END IF;
  IF p_reply_to IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.messages
    WHERE id = p_reply_to AND conversation_id = p_conversation
  ) THEN
    RAISE EXCEPTION 'Reply target is not in this conversation' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.messages (id, conversation_id, sender_id, type, body, media, reply_to)
  VALUES (coalesce(p_id, gen_random_uuid()), p_conversation, auth.uid(), p_type, p_body, p_media, p_reply_to)
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.send_message(UUID, UUID, TEXT, TEXT, JSONB, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_message(UUID, UUID, TEXT, TEXT, JSONB, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation UUID, p_seq BIGINT)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.conversation_members
  SET last_read_seq = GREATEST(coalesce(last_read_seq, 0), p_seq)
  WHERE conversation_id = p_conversation AND user_id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.mark_conversation_read(UUID, BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(UUID, BIGINT) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_contact_blocked(p_contact UUID, p_blocked BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_contact = auth.uid() THEN
    RAISE EXCEPTION 'Invalid contact' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.contacts (owner_id, contact_id, status)
  VALUES (auth.uid(), p_contact, CASE WHEN p_blocked THEN 'blocked' ELSE 'accepted' END)
  ON CONFLICT (owner_id, contact_id)
  DO UPDATE SET status = CASE WHEN p_blocked THEN 'blocked' ELSE 'accepted' END,
                updated_at = NOW();
END;
$$;
REVOKE ALL ON FUNCTION public.set_contact_blocked(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_contact_blocked(UUID, BOOLEAN) TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_message_search()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.message_search WHERE message_id = OLD.id;
    RETURN OLD;
  END IF;
  INSERT INTO public.message_search (message_id, conversation_id, content_tsv)
  VALUES (
    NEW.id,
    NEW.conversation_id,
    to_tsvector('simple', coalesce(NEW.body, ''))
  )
  ON CONFLICT (message_id) DO UPDATE
    SET conversation_id = EXCLUDED.conversation_id,
        content_tsv = EXCLUDED.content_tsv;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_message_search ON public.messages;
CREATE TRIGGER trg_sync_message_search
  AFTER INSERT OR UPDATE OF body ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.sync_message_search();

INSERT INTO public.message_search (message_id, conversation_id, content_tsv)
SELECT m.id, m.conversation_id, to_tsvector('simple', coalesce(m.body, ''))
FROM public.messages m
WHERE NOT EXISTS (SELECT 1 FROM public.message_search s WHERE s.message_id = m.id);

CREATE OR REPLACE FUNCTION public.search_messages(p_query TEXT, p_limit INTEGER DEFAULT 30)
RETURNS TABLE (
  message_id UUID,
  conversation_id UUID,
  sender_id UUID,
  body TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT m.id, m.conversation_id, m.sender_id, m.body, m.created_at
  FROM public.message_search s
  JOIN public.messages m ON m.id = s.message_id
  WHERE auth.uid() IS NOT NULL
    AND public.is_conversation_member(m.conversation_id, auth.uid())
    AND m.deleted_at IS NULL
    AND coalesce(trim(p_query), '') <> ''
    AND s.content_tsv @@ websearch_to_tsquery('simple', p_query)
  ORDER BY m.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$$;
REVOKE ALL ON FUNCTION public.search_messages(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_messages(TEXT, INTEGER) TO authenticated;

-- ---------------------------------------------------------------------------
-- Reports and discovery subscriptions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL DEFAULT 'account' CHECK (target_type IN ('account','message','group','channel','moment','problem')),
  target_id TEXT NOT NULL,
  target_name TEXT,
  reason TEXT NOT NULL,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','resolved','dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reports_insert_own ON public.reports;
CREATE POLICY reports_insert_own ON public.reports
  FOR INSERT WITH CHECK (reporter_id = auth.uid());
DROP POLICY IF EXISTS reports_select_own ON public.reports;
CREATE POLICY reports_select_own ON public.reports
  FOR SELECT USING (reporter_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (owner_id, blocked_id),
  CHECK (owner_id <> blocked_id)
);
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS blocks_own ON public.blocks;
CREATE POLICY blocks_own ON public.blocks
  FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks (blocked_id);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON public.audit_log (actor_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT,
  rollout_percent INTEGER NOT NULL DEFAULT 100 CHECK (rollout_percent BETWEEN 0 AND 100),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS feature_flags_read ON public.feature_flags;
CREATE POLICY feature_flags_read ON public.feature_flags FOR SELECT USING (TRUE);

INSERT INTO public.feature_flags (key, enabled, description, rollout_percent)
VALUES
  ('wallet', false, 'Wallet, payments and red packets', 0),
  ('calls', true, 'Voice and video calls', 100),
  ('channels', true, 'Channels and short video', 100),
  ('moments', true, 'Moments social feed', 100),
  ('mini_programs', true, 'Mini program container', 100),
  ('e2ee', false, 'End-to-end encrypted 1:1 chats', 0)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.channel_subscriptions (
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (channel_id, user_id)
);
ALTER TABLE public.channel_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS channel_subscriptions_own ON public.channel_subscriptions;
CREATE POLICY channel_subscriptions_own ON public.channel_subscriptions
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.oa_bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  oa_id UUID NOT NULL REFERENCES public.official_accounts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.oa_posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (oa_id, user_id, post_id)
);
ALTER TABLE public.oa_bookmarks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oa_bookmarks_own ON public.oa_bookmarks;
CREATE POLICY oa_bookmarks_own ON public.oa_bookmarks
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Moments privacy fixes
CREATE OR REPLACE FUNCTION public.can_view_moment(p_moment UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.moments m
    WHERE m.id = p_moment
      AND m.deleted_at IS NULL
      AND (
        m.author_id = auth.uid()
        OR m.visibility = 'all'
        OR (
          m.visibility = 'friends'
          AND EXISTS (
            SELECT 1 FROM public.contacts c
            WHERE c.status = 'accepted'
              AND (
                (c.owner_id = auth.uid() AND c.contact_id = m.author_id)
                OR (c.contact_id = auth.uid() AND c.owner_id = m.author_id)
              )
          )
        )
      )
  );
$$;
REVOKE ALL ON FUNCTION public.can_view_moment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_view_moment(UUID) TO authenticated;

DROP POLICY IF EXISTS moments_read ON public.moments;
CREATE POLICY moments_read ON public.moments
  FOR SELECT USING (public.can_view_moment(id));

DROP POLICY IF EXISTS moment_likes_all ON public.moment_likes;
DROP POLICY IF EXISTS moment_likes_read ON public.moment_likes;
DROP POLICY IF EXISTS moment_likes_own ON public.moment_likes;
DROP POLICY IF EXISTS moment_likes_insert ON public.moment_likes;
DROP POLICY IF EXISTS moment_likes_delete ON public.moment_likes;
CREATE POLICY moment_likes_read ON public.moment_likes
  FOR SELECT USING (public.can_view_moment(moment_id));
CREATE POLICY moment_likes_insert ON public.moment_likes
  FOR INSERT WITH CHECK (user_id = auth.uid() AND public.can_view_moment(moment_id));
CREATE POLICY moment_likes_delete ON public.moment_likes
  FOR DELETE USING (user_id = auth.uid());

DROP POLICY IF EXISTS moment_comments_all ON public.moment_comments;
DROP POLICY IF EXISTS moment_comments_read ON public.moment_comments;
DROP POLICY IF EXISTS moment_comments_insert ON public.moment_comments;
DROP POLICY IF EXISTS moment_comments_own ON public.moment_comments;
DROP POLICY IF EXISTS moment_comments_delete ON public.moment_comments;
CREATE POLICY moment_comments_read ON public.moment_comments
  FOR SELECT USING (public.can_view_moment(moment_id));
CREATE POLICY moment_comments_insert ON public.moment_comments
  FOR INSERT WITH CHECK (author_id = auth.uid() AND public.can_view_moment(moment_id));
CREATE POLICY moment_comments_own ON public.moment_comments
  FOR UPDATE USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY moment_comments_delete ON public.moment_comments
  FOR DELETE USING (
    author_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.moments m WHERE m.id = moment_id AND m.author_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Wallet RPC surface
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.wallet_ensure()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.wallets (user_id) VALUES (auth.uid())
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_ensure() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_ensure() TO authenticated;

CREATE OR REPLACE FUNCTION public.wallet_balance()
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(sum(
    CASE WHEN direction = 'credit' THEN amount_minor ELSE -amount_minor END
  ), 0)::BIGINT
  FROM public.ledger_entries
  WHERE account = auth.uid()::text;
$$;
REVOKE ALL ON FUNCTION public.wallet_balance() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_balance() TO authenticated;

CREATE OR REPLACE FUNCTION public.wallet_summary()
RETURNS TABLE (currency TEXT, balance_minor BIGINT, wallet_status TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(w.currency, 'ETB'), public.wallet_balance(), coalesce(w.status, 'none')
  FROM (SELECT auth.uid() AS user_id) me
  LEFT JOIN public.wallets w ON w.user_id = me.user_id;
$$;
REVOKE ALL ON FUNCTION public.wallet_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.wallet_topup(
  p_user UUID,
  p_amount_minor BIGINT,
  p_idempotency_key TEXT,
  p_provider TEXT DEFAULT 'telebirr',
  p_provider_ref TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_txn UUID;
BEGIN
  IF p_amount_minor IS NULL OR p_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive' USING ERRCODE = '22023';
  END IF;
  IF coalesce(trim(p_idempotency_key), '') = '' THEN
    RAISE EXCEPTION 'Idempotency key is required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_txn FROM public.transactions WHERE idempotency_key = p_idempotency_key;
  IF v_txn IS NOT NULL THEN RETURN v_txn; END IF;

  INSERT INTO public.wallets (user_id) VALUES (p_user)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.transactions (user_id, type, status, amount_minor, provider, provider_ref, idempotency_key, meta)
  VALUES (p_user, 'topup', 'success', p_amount_minor, p_provider, p_provider_ref, p_idempotency_key,
          jsonb_build_object('source', 'provider'))
  RETURNING id INTO v_txn;

  INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
  VALUES
    (v_txn, 'system:topup', 'debit', p_amount_minor),
    (v_txn, p_user::text, 'credit', p_amount_minor);
  RETURN v_txn;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_topup(UUID, BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_topup(UUID, BIGINT, TEXT, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.wallet_transfer(
  p_recipient UUID,
  p_amount_minor BIGINT,
  p_idempotency_key TEXT,
  p_note TEXT DEFAULT NULL,
  p_sender UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := coalesce(p_sender, auth.uid());
  v_txn UUID;
  v_balance BIGINT;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_sender IS NOT NULL AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE = '42501';
  END IF;
  IF p_amount_minor IS NULL OR p_amount_minor <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive' USING ERRCODE = '22023';
  END IF;
  IF p_recipient IS NULL OR p_recipient = v_me THEN
    RAISE EXCEPTION 'Choose another recipient' USING ERRCODE = '22023';
  END IF;
  IF coalesce(trim(p_idempotency_key), '') = '' THEN
    RAISE EXCEPTION 'Idempotency key is required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_txn FROM public.transactions WHERE idempotency_key = p_idempotency_key;
  IF v_txn IS NOT NULL THEN RETURN v_txn; END IF;

  INSERT INTO public.wallets (user_id) VALUES (v_me), (p_recipient)
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM 1 FROM public.wallets
  WHERE user_id IN (v_me, p_recipient)
  ORDER BY user_id
  FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = p_recipient AND status = 'active') THEN
    RAISE EXCEPTION 'Recipient wallet is not active' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = v_me AND status = 'active') THEN
    RAISE EXCEPTION 'Your wallet is not active' USING ERRCODE = '42501';
  END IF;

  SELECT public.wallet_balance() INTO v_balance;
  IF v_balance < p_amount_minor THEN
    RAISE EXCEPTION 'Insufficient balance' USING ERRCODE = '22003';
  END IF;

  INSERT INTO public.transactions (user_id, type, status, amount_minor, idempotency_key, meta)
  VALUES (v_me, 'p2p', 'success', p_amount_minor, p_idempotency_key,
          jsonb_build_object('recipient', p_recipient, 'note', p_note))
  RETURNING id INTO v_txn;

  INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
  VALUES
    (v_txn, v_me::text, 'debit', p_amount_minor),
    (v_txn, p_recipient::text, 'credit', p_amount_minor);
  RETURN v_txn;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_transfer(UUID, BIGINT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_transfer(UUID, BIGINT, TEXT, TEXT, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.wallet_create_redpacket(
  p_conversation UUID,
  p_total_minor BIGINT,
  p_count INTEGER,
  p_mode TEXT DEFAULT 'random',
  p_expires_in INTERVAL DEFAULT INTERVAL '24 hours',
  p_idempotency_key TEXT DEFAULT NULL,
  p_sender UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := coalesce(p_sender, auth.uid());
  v_id UUID;
  v_txn UUID;
  v_balance BIGINT;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_sender IS NOT NULL AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE = '42501';
  END IF;
  IF p_total_minor <= 0 OR p_count <= 0 OR p_total_minor < p_count THEN
    RAISE EXCEPTION 'Invalid red packet amount or count' USING ERRCODE = '22023';
  END IF;
  IF p_mode NOT IN ('random', 'equal') THEN
    RAISE EXCEPTION 'Invalid mode' USING ERRCODE = '22023';
  END IF;
  IF p_conversation IS NOT NULL AND NOT public.is_conversation_member(p_conversation, v_me) THEN
    RAISE EXCEPTION 'You are not in this conversation' USING ERRCODE = '42501';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_id FROM public.redpackets
    WHERE sender_id = v_me AND id = (
      SELECT (meta->>'redpacket_id')::uuid FROM public.transactions
      WHERE idempotency_key = p_idempotency_key AND user_id = v_me
    );
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  END IF;

  INSERT INTO public.wallets (user_id) VALUES (v_me) ON CONFLICT (user_id) DO NOTHING;
  PERFORM 1 FROM public.wallets WHERE user_id = v_me FOR UPDATE;
  SELECT public.wallet_balance() INTO v_balance;
  IF v_balance < p_total_minor THEN
    RAISE EXCEPTION 'Insufficient balance' USING ERRCODE = '22003';
  END IF;

  INSERT INTO public.redpackets (sender_id, conversation_id, total_minor, count, mode, expires_at)
  VALUES (v_me, p_conversation, p_total_minor, p_count, p_mode, NOW() + p_expires_in)
  RETURNING id INTO v_id;

  INSERT INTO public.transactions (user_id, type, status, amount_minor, idempotency_key, meta)
  VALUES (v_me, 'redpacket', 'success', p_total_minor, p_idempotency_key,
          jsonb_build_object('redpacket_id', v_id))
  RETURNING id INTO v_txn;

  INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
  VALUES
    (v_txn, v_me::text, 'debit', p_total_minor),
    (v_txn, 'redpacket:' || v_id::text, 'credit', p_total_minor);

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_create_redpacket(UUID, BIGINT, INTEGER, TEXT, INTERVAL, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_create_redpacket(UUID, BIGINT, INTEGER, TEXT, INTERVAL, TEXT, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.wallet_claim_redpacket(
  p_redpacket UUID,
  p_claimer UUID DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := coalesce(p_claimer, auth.uid());
  v_packet public.redpackets;
  v_claimed_count INTEGER;
  v_claimed_total BIGINT;
  v_remaining BIGINT;
  v_slots INTEGER;
  v_amount BIGINT;
  v_txn UUID;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_claimer IS NOT NULL AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_packet FROM public.redpackets WHERE id = p_redpacket FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Red packet not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_packet.sender_id = v_me THEN
    RAISE EXCEPTION 'You cannot claim your own red packet' USING ERRCODE = '22023';
  END IF;
  IF v_packet.expires_at <= NOW() THEN
    RAISE EXCEPTION 'This red packet has expired' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.redpacket_claims WHERE redpacket_id = p_redpacket AND claimer_id = v_me) THEN
    RAISE EXCEPTION 'You already claimed this red packet' USING ERRCODE = '23505';
  END IF;

  SELECT count(*), coalesce(sum(amount_minor), 0)
  INTO v_claimed_count, v_claimed_total
  FROM public.redpacket_claims WHERE redpacket_id = p_redpacket;

  IF v_claimed_count >= v_packet.count THEN
    RAISE EXCEPTION 'This red packet is empty' USING ERRCODE = '22023';
  END IF;

  v_remaining := v_packet.total_minor - v_claimed_total;
  v_slots := v_packet.count - v_claimed_count;

  IF v_packet.mode = 'equal' THEN
    v_amount := v_remaining / v_slots;
  ELSE
    v_amount := floor(random() * (v_remaining - v_slots + 1))::bigint + 1;
    IF v_slots > 1 THEN
      v_amount := least(v_amount, v_remaining - (v_slots - 1));
    END IF;
  END IF;
  IF v_slots = 1 THEN v_amount := v_remaining; END IF;
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Red packet has no balance left' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.redpacket_claims (redpacket_id, claimer_id, amount_minor)
  VALUES (p_redpacket, v_me, v_amount);

  INSERT INTO public.transactions (user_id, type, status, amount_minor, meta)
  VALUES (v_me, 'redpacket', 'success', v_amount,
          jsonb_build_object('redpacket_id', p_redpacket, 'claim', true))
  RETURNING id INTO v_txn;

  INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
  VALUES
    (v_txn, 'redpacket:' || p_redpacket::text, 'debit', v_amount),
    (v_txn, v_me::text, 'credit', v_amount);

  RETURN v_amount;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_claim_redpacket(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_claim_redpacket(UUID, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.wallet_set_pin(p_pin TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_pin !~ '^[0-9]{4,6}$' THEN
    RAISE EXCEPTION 'PIN must be 4 to 6 digits' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.pin_secrets (user_id, pin_hash)
  VALUES (auth.uid(), crypt(p_pin, gen_salt('bf', 10)))
  ON CONFLICT (user_id) DO UPDATE
    SET pin_hash = EXCLUDED.pin_hash,
        attempts = 0,
        locked_until = NULL,
        updated_at = NOW();
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_set_pin(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_set_pin(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.wallet_verify_pin(p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.pin_secrets;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_row FROM public.pin_secrets WHERE user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RETURN FALSE; END IF;
  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RAISE EXCEPTION 'Wallet PIN is temporarily locked' USING ERRCODE = '42501';
  END IF;
  IF v_row.pin_hash = crypt(p_pin, v_row.pin_hash) THEN
    UPDATE public.pin_secrets SET attempts = 0, locked_until = NULL, updated_at = NOW()
    WHERE user_id = auth.uid();
    RETURN TRUE;
  END IF;
  UPDATE public.pin_secrets
  SET attempts = coalesce(attempts, 0) + 1,
      locked_until = CASE WHEN coalesce(attempts, 0) + 1 >= 5 THEN NOW() + INTERVAL '5 minutes' ELSE NULL END,
      updated_at = NOW()
  WHERE user_id = auth.uid();
  RETURN FALSE;
END;
$$;
REVOKE ALL ON FUNCTION public.wallet_verify_pin(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_verify_pin(TEXT) TO authenticated;

-- Wallet mutations go through the functions above.
DROP POLICY IF EXISTS wallets_own ON public.wallets;
DROP POLICY IF EXISTS wallets_select_own ON public.wallets;
CREATE POLICY wallets_select_own ON public.wallets
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
DROP POLICY IF EXISTS redpackets_insert ON public.redpackets;
DROP POLICY IF EXISTS redpacket_claims_all ON public.redpacket_claims;
DROP POLICY IF EXISTS pin_own ON public.pin_secrets;

-- ---------------------------------------------------------------------------
-- Storage buckets and object policies
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', TRUE, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('media', 'media', FALSE, 104857600, NULL),
  ('mini-programs', 'mini-programs', TRUE, 52428800, NULL)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS avatars_insert_own ON storage.objects;
DROP POLICY IF EXISTS avatars_update_own ON storage.objects;
DROP POLICY IF EXISTS avatars_read ON storage.objects;
CREATE POLICY avatars_read ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY avatars_insert_own ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY avatars_update_own ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  ) WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS media_insert_member ON storage.objects;
DROP POLICY IF EXISTS media_read_member ON storage.objects;
CREATE POLICY media_read_member ON storage.objects
  FOR SELECT USING (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND public.is_conversation_member(
      NULLIF(split_part(name, '/', 1), '')::uuid,
      auth.uid()
    )
  );
CREATE POLICY media_insert_member ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND public.is_conversation_member(
      NULLIF(split_part(name, '/', 1), '')::uuid,
      auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- Integrity guards
-- ---------------------------------------------------------------------------
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_amount_positive;
ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_amount_positive CHECK (amount_minor > 0) NOT VALID;
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_fee_nonnegative;
ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_fee_nonnegative CHECK (fee_minor >= 0) NOT VALID;
ALTER TABLE public.ledger_entries
  DROP CONSTRAINT IF EXISTS ledger_amount_positive;
ALTER TABLE public.ledger_entries
  ADD CONSTRAINT ledger_amount_positive CHECK (amount_minor > 0) NOT VALID;

-- ledger_entries is append-only for ordinary users.
REVOKE ALL ON public.ledger_entries FROM anon, authenticated;
GRANT SELECT ON public.ledger_entries TO authenticated;
