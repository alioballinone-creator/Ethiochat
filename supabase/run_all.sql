ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.is_conversation_member(cid UUID, uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = cid AND user_id = uid AND left_at IS NULL
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
DROP POLICY IF EXISTS profiles_select_self ON public.profiles;
CREATE POLICY profiles_select_self ON public.profiles
  FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS profiles_update_self ON public.profiles;
CREATE POLICY profiles_update_self ON public.profiles
  FOR UPDATE USING (id = auth.uid());
DROP POLICY IF EXISTS profiles_insert_self ON public.profiles;
CREATE POLICY profiles_insert_self ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());
DROP POLICY IF EXISTS devices_all_own ON public.devices;
CREATE POLICY devices_all_own ON public.devices
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS contacts_owner ON public.contacts;
CREATE POLICY contacts_owner ON public.contacts
  FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
DROP POLICY IF EXISTS conversations_select_member ON public.conversations;
CREATE POLICY conversations_select_member ON public.conversations
  FOR SELECT USING (public.is_conversation_member(id, auth.uid()));
DROP POLICY IF EXISTS conversations_update_creator_or_admin ON public.conversations;
CREATE POLICY conversations_update_creator_or_admin ON public.conversations
  FOR UPDATE USING (
    created_by = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );
DROP POLICY IF EXISTS members_select ON public.conversation_members;
CREATE POLICY members_select ON public.conversation_members
  FOR SELECT USING (public.is_conversation_member(conversation_id, auth.uid()) OR user_id = auth.uid());
DROP POLICY IF EXISTS members_insert ON public.conversation_members;
CREATE POLICY members_insert ON public.conversation_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );
DROP POLICY IF EXISTS members_update ON public.conversation_members;
CREATE POLICY members_update ON public.conversation_members
  FOR UPDATE USING (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );
DROP POLICY IF EXISTS messages_select_member ON public.messages;
CREATE POLICY messages_select_member ON public.messages
  FOR SELECT USING (public.is_conversation_member(conversation_id, auth.uid()));
DROP POLICY IF EXISTS messages_insert_member ON public.messages;
CREATE POLICY messages_insert_member ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND public.is_conversation_member(conversation_id, auth.uid())
  );
DROP POLICY IF EXISTS messages_update_sender ON public.messages;
CREATE POLICY messages_update_sender ON public.messages
  FOR UPDATE USING (sender_id = auth.uid());
DROP POLICY IF EXISTS receipts_select_member ON public.message_receipts;
CREATE POLICY receipts_select_member ON public.message_receipts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id, auth.uid())
    )
  );
DROP POLICY IF EXISTS receipts_upsert_self ON public.message_receipts;
CREATE POLICY receipts_upsert_self ON public.message_receipts
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_duration_ms INTEGER;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_waveform JSONB;
CREATE TABLE IF NOT EXISTS public.prekeys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE,
  key_id INTEGER NOT NULL,
  public_key BYTEA NOT NULL,
  signature BYTEA,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, device_id, key_id)
);
CREATE TABLE IF NOT EXISTS public.onetime_prekeys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE,
  key_id INTEGER NOT NULL,
  public_key BYTEA NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, device_id, key_id)
);
CREATE TABLE IF NOT EXISTS public.signed_prekeys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE,
  key_id INTEGER NOT NULL,
  public_key BYTEA NOT NULL,
  signature BYTEA NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS public.calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id),
  caller_id UUID NOT NULL REFERENCES auth.users(id),
  callee_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL CHECK (type IN ('voice','video')),
  status TEXT NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing','accepted','rejected','ended','missed','busy')),
  livekit_room TEXT,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.call_participants (
  call_id UUID NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  PRIMARY KEY (call_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.message_search (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL,
  content_tsv TSVECTOR
);
CREATE INDEX IF NOT EXISTS idx_message_search_tsv ON public.message_search USING GIN (content_tsv);
CREATE INDEX IF NOT EXISTS idx_calls_conv ON public.calls (conversation_id, created_at DESC);
ALTER TABLE public.prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onetime_prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signed_prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_search ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS prekeys_select ON public.prekeys;
CREATE POLICY prekeys_select ON public.prekeys FOR SELECT USING (true);
DROP POLICY IF EXISTS prekeys_manage_own ON public.prekeys;
CREATE POLICY prekeys_manage_own ON public.prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS onetime_prekeys_select ON public.onetime_prekeys;
CREATE POLICY onetime_prekeys_select ON public.onetime_prekeys FOR SELECT USING (true);
DROP POLICY IF EXISTS onetime_prekeys_manage_own ON public.onetime_prekeys;
CREATE POLICY onetime_prekeys_manage_own ON public.onetime_prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS signed_prekeys_select ON public.signed_prekeys;
CREATE POLICY signed_prekeys_select ON public.signed_prekeys FOR SELECT USING (true);
DROP POLICY IF EXISTS signed_prekeys_manage_own ON public.signed_prekeys;
CREATE POLICY signed_prekeys_manage_own ON public.signed_prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS calls_select_member ON public.calls;
CREATE POLICY calls_select_member ON public.calls FOR SELECT USING (
  caller_id = auth.uid() OR callee_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = calls.conversation_id AND cm.user_id = auth.uid())
);
DROP POLICY IF EXISTS calls_insert ON public.calls;
CREATE POLICY calls_insert ON public.calls FOR INSERT WITH CHECK (caller_id = auth.uid());
DROP POLICY IF EXISTS call_participants_all ON public.call_participants;
CREATE POLICY call_participants_all ON public.call_participants FOR ALL USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.calls c WHERE c.id = call_id AND c.caller_id = auth.uid())
) WITH CHECK (user_id = auth.uid());
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  currency TEXT NOT NULL DEFAULT 'ETB',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_id UUID NOT NULL,
  account TEXT NOT NULL, -- user_id or system account
  direction TEXT NOT NULL CHECK (direction IN ('debit','credit')),
  amount_minor BIGINT NOT NULL CHECK (amount_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'ETB',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ledger_txn ON public.ledger_entries (txn_id);
CREATE INDEX IF NOT EXISTS idx_ledger_account ON public.ledger_entries (account, created_at);
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL CHECK (type IN ('topup','p2p','redpacket','merchant','withdraw','bill')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','success','failed','reversed')),
  amount_minor BIGINT NOT NULL,
  fee_minor BIGINT DEFAULT 0,
  provider TEXT,
  provider_ref TEXT,
  idempotency_key TEXT UNIQUE,
  meta JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.redpackets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  conversation_id UUID REFERENCES public.conversations(id),
  total_minor BIGINT NOT NULL CHECK (total_minor > 0),
  count INTEGER NOT NULL CHECK (count > 0),
  mode TEXT NOT NULL DEFAULT 'random' CHECK (mode IN ('random','equal')),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.redpacket_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redpacket_id UUID NOT NULL REFERENCES public.redpackets(id) ON DELETE CASCADE,
  claimer_id UUID NOT NULL REFERENCES auth.users(id),
  amount_minor BIGINT NOT NULL,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (redpacket_id, claimer_id)
);
CREATE TABLE IF NOT EXISTS public.pin_secrets (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  pin_hash TEXT NOT NULL,
  attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.kyc (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier INTEGER NOT NULL DEFAULT 0 CHECK (tier IN (0,1,2)),
  status TEXT DEFAULT 'pending',
  data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redpackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redpacket_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pin_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallets_own ON public.wallets;
CREATE POLICY wallets_own ON public.wallets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS ledger_read_own ON public.ledger_entries;
CREATE POLICY ledger_read_own ON public.ledger_entries FOR SELECT USING (account = auth.uid()::text);
DROP POLICY IF EXISTS transactions_own ON public.transactions;
CREATE POLICY transactions_own ON public.transactions FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
CREATE POLICY transactions_insert_own ON public.transactions FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS redpackets_select ON public.redpackets;
CREATE POLICY redpackets_select ON public.redpackets FOR SELECT USING (true);
DROP POLICY IF EXISTS redpackets_insert ON public.redpackets;
CREATE POLICY redpackets_insert ON public.redpackets FOR INSERT WITH CHECK (sender_id = auth.uid());
DROP POLICY IF EXISTS redpacket_claims_all ON public.redpacket_claims;
CREATE POLICY redpacket_claims_all ON public.redpacket_claims FOR ALL USING (claimer_id = auth.uid()) WITH CHECK (claimer_id = auth.uid());
DROP POLICY IF EXISTS pin_own ON public.pin_secrets;
CREATE POLICY pin_own ON public.pin_secrets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS kyc_own ON public.kyc;
CREATE POLICY kyc_own ON public.kyc FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
REVOKE UPDATE, DELETE ON public.ledger_entries FROM anon, authenticated;
CREATE TABLE IF NOT EXISTS public.moments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT,
  media JSONB DEFAULT '[]'::jsonb,
  visibility TEXT NOT NULL DEFAULT 'friends' CHECK (visibility IN ('all','friends','selected','private')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS public.moment_likes (
  moment_id UUID NOT NULL REFERENCES public.moments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (moment_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.moment_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  moment_id UUID NOT NULL REFERENCES public.moments(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  avatar_url TEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.channel_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('video','image','article')),
  caption TEXT,
  media_url TEXT,
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.official_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  verified BOOLEAN DEFAULT TRUE,
  category TEXT,
  avatar_url TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.oa_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  oa_id UUID NOT NULL REFERENCES public.official_accounts(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  media JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.oa_subscriptions (
  oa_id UUID NOT NULL REFERENCES public.official_accounts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (oa_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.mini_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  icon_url TEXT,
  manifest_url TEXT NOT NULL,
  version TEXT NOT NULL,
  publisher_id UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'approved' CHECK (status IN ('pending','approved','rejected','suspended')),
  permissions JSONB DEFAULT '[]'::jsonb,
  bundle_hash TEXT,
  signature TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.moments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moment_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.official_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oa_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oa_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mini_programs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS moments_read ON public.moments;
CREATE POLICY moments_read ON public.moments FOR SELECT USING (true);
DROP POLICY IF EXISTS moments_own ON public.moments;
CREATE POLICY moments_own ON public.moments FOR ALL USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS moment_likes_all ON public.moment_likes;
CREATE POLICY moment_likes_all ON public.moment_likes FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS moment_comments_all ON public.moment_comments;
CREATE POLICY moment_comments_all ON public.moment_comments FOR ALL USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS channels_read ON public.channels;
CREATE POLICY channels_read ON public.channels FOR SELECT USING (true);
DROP POLICY IF EXISTS channel_posts_read ON public.channel_posts;
CREATE POLICY channel_posts_read ON public.channel_posts FOR SELECT USING (true);
DROP POLICY IF EXISTS oa_read ON public.official_accounts;
CREATE POLICY oa_read ON public.official_accounts FOR SELECT USING (true);
DROP POLICY IF EXISTS oa_posts_read ON public.oa_posts;
CREATE POLICY oa_posts_read ON public.oa_posts FOR SELECT USING (true);
DROP POLICY IF EXISTS oa_subs_all ON public.oa_subscriptions;
CREATE POLICY oa_subs_all ON public.oa_subscriptions FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS miniprograms_read ON public.mini_programs;
CREATE POLICY miniprograms_read ON public.mini_programs FOR SELECT USING (status = 'approved');
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
DROP FUNCTION IF EXISTS public.is_conversation_member(UUID, UUID);
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
DROP POLICY IF EXISTS moment_comments_delete ON public.moment_comments;
CREATE POLICY moment_comments_delete ON public.moment_comments
  FOR DELETE USING (
    author_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.moments m WHERE m.id = moment_id AND m.author_id = auth.uid())
  );
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
  SELECT id INTO v_txn FROM public.transactions
  WHERE idempotency_key = p_idempotency_key AND user_id = v_me;
  IF v_txn IS NOT NULL THEN RETURN v_txn; END IF;
  IF EXISTS (SELECT 1 FROM public.transactions WHERE idempotency_key = p_idempotency_key) THEN
    RAISE EXCEPTION 'Idempotency key already belongs to another transfer' USING ERRCODE = '23505';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_recipient) THEN
    RAISE EXCEPTION 'Recipient not found' USING ERRCODE = 'P0002';
  END IF;
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
  SELECT coalesce(sum(
    CASE WHEN direction = 'credit' THEN amount_minor ELSE -amount_minor END
  ), 0)::BIGINT
  INTO v_balance
  FROM public.ledger_entries
  WHERE account = v_me::text;
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
  IF p_total_minor <= 0 OR p_count <= 0 OR p_total_minor < p_count * 100 THEN
    RAISE EXCEPTION 'Each share must be at least 1 ETB' USING ERRCODE = '22023';
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
  SELECT coalesce(sum(
    CASE WHEN direction = 'credit' THEN amount_minor ELSE -amount_minor END
  ), 0)::BIGINT
  INTO v_balance
  FROM public.ledger_entries
  WHERE account = v_me::text;
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
    v_amount := floor(random() * (v_remaining - v_slots * 100 + 1))::bigint + 100;
    IF v_slots > 1 THEN
      v_amount := least(v_amount, v_remaining - (v_slots - 1) * 100);
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
DROP POLICY IF EXISTS wallets_own ON public.wallets;
DROP POLICY IF EXISTS wallets_select_own ON public.wallets;
CREATE POLICY wallets_select_own ON public.wallets
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
DROP POLICY IF EXISTS redpackets_insert ON public.redpackets;
DROP POLICY IF EXISTS redpacket_claims_all ON public.redpacket_claims;
DROP POLICY IF EXISTS pin_own ON public.pin_secrets;
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
DROP POLICY IF EXISTS avatars_update_own ON storage.objects;
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
DROP POLICY IF EXISTS media_insert_member ON storage.objects;
CREATE POLICY media_insert_member ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'media'
    AND auth.uid() IS NOT NULL
    AND public.is_conversation_member(
      NULLIF(split_part(name, '/', 1), '')::uuid,
      auth.uid()
    )
  );
ALTER TABLE public.redpackets
  DROP CONSTRAINT IF EXISTS redpackets_minimum_share;
ALTER TABLE public.redpackets
  ADD CONSTRAINT redpackets_minimum_share CHECK (total_minor >= count * 100) NOT VALID;
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
REVOKE ALL ON public.ledger_entries FROM anon, authenticated;
GRANT SELECT ON public.ledger_entries TO authenticated;
CREATE EXTENSION IF NOT EXISTS pg_cron;
ALTER TABLE public.redpackets
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_redpackets_expiry
  ON public.redpackets (expires_at)
  WHERE refunded_at IS NULL;
CREATE OR REPLACE FUNCTION public.expire_redpackets()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_packet public.redpackets;
  v_claimed BIGINT;
  v_remaining BIGINT;
  v_txn UUID;
  v_count INTEGER := 0;
BEGIN
  FOR v_packet IN
    SELECT * FROM public.redpackets
    WHERE expires_at <= NOW() AND refunded_at IS NULL
    ORDER BY expires_at
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT coalesce(sum(amount_minor), 0)
      INTO v_claimed
      FROM public.redpacket_claims
      WHERE redpacket_id = v_packet.id;
    v_remaining := v_packet.total_minor - v_claimed;
    IF v_remaining > 0 THEN
      INSERT INTO public.transactions
        (user_id, type, status, amount_minor, idempotency_key, meta)
      VALUES
        (v_packet.sender_id, 'redpacket', 'success', v_remaining,
         'redpacket-refund:' || v_packet.id::text,
         jsonb_build_object('redpacket_id', v_packet.id, 'refund', true))
      RETURNING id INTO v_txn;
      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn, 'redpacket:' || v_packet.id::text, 'debit', v_remaining),
        (v_txn, v_packet.sender_id::text, 'credit', v_remaining);
    END IF;
    UPDATE public.redpackets
      SET refunded_at = NOW()
      WHERE id = v_packet.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.expire_redpackets() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_redpackets() TO service_role;
CREATE OR REPLACE FUNCTION public.purge_soft_deleted_media()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH purged AS (
    UPDATE public.messages
    SET media = NULL
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - INTERVAL '30 days'
      AND media IS NOT NULL
    RETURNING 1
  )
  SELECT count(*)::INTEGER FROM purged;
$$;
REVOKE ALL ON FUNCTION public.purge_soft_deleted_media() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_soft_deleted_media() TO service_role;
CREATE TABLE IF NOT EXISTS public.daily_stats (
  day DATE PRIMARY KEY,
  users INTEGER NOT NULL DEFAULT 0,
  messages INTEGER NOT NULL DEFAULT 0,
  transactions INTEGER NOT NULL DEFAULT 0,
  volume_minor BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.daily_stats ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.rebuild_daily_stats(p_day DATE DEFAULT CURRENT_DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.daily_stats (day, users, messages, transactions, volume_minor)
  VALUES (
    p_day,
    (SELECT count(*) FROM public.profiles WHERE created_at::date <= p_day),
    (SELECT count(*) FROM public.messages WHERE created_at::date = p_day AND deleted_at IS NULL),
    (SELECT count(*) FROM public.transactions WHERE created_at::date = p_day),
    (SELECT coalesce(sum(amount_minor), 0) FROM public.transactions
      WHERE created_at::date = p_day AND status = 'success')
  )
  ON CONFLICT (day) DO UPDATE
    SET users = EXCLUDED.users,
        messages = EXCLUDED.messages,
        transactions = EXCLUDED.transactions,
        volume_minor = EXCLUDED.volume_minor;
END;
$$;
REVOKE ALL ON FUNCTION public.rebuild_daily_stats(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_daily_stats(DATE) TO service_role;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-expire-redpackets') THEN
    PERFORM cron.unschedule('ethiochat-expire-redpackets');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-purge-media') THEN
    PERFORM cron.unschedule('ethiochat-purge-media');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-daily-stats') THEN
    PERFORM cron.unschedule('ethiochat-daily-stats');
  END IF;
  PERFORM cron.schedule(
    'ethiochat-expire-redpackets',
    '*/5 * * * *',
    'SELECT public.expire_redpackets();'
  );
  PERFORM cron.schedule(
    'ethiochat-purge-media',
    '15 3 * * *',
    'SELECT public.purge_soft_deleted_media();'
  );
  PERFORM cron.schedule(
    'ethiochat-daily-stats',
    '10 0 * * *',
    'SELECT public.rebuild_daily_stats(CURRENT_DATE - 1);'
  );
END;
$$;
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
        AND tablename = 'messages'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.messages';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'conversations'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations';
    END IF;
  END IF;
END
$$;
BEGIN;
DROP POLICY IF EXISTS calls_insert ON public.calls;
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
BEGIN;
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
UPDATE public.profiles p
SET role = 'admin'
FROM public.admin_users a
WHERE a.user_id = p.id
  AND p.role <> 'admin';
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
CREATE TABLE IF NOT EXISTS public.staff_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'moderator', 'support', 'finance', 'content')),
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
INSERT INTO public.staff_roles (user_id, role)
SELECT id, 'admin' FROM public.profiles WHERE role = 'admin'
ON CONFLICT (user_id) DO NOTHING;
INSERT INTO public.staff_roles (user_id, role, assigned_by)
SELECT user_id, 'owner', created_by
FROM public.admin_users
ORDER BY created_at, user_id
LIMIT 1
ON CONFLICT (user_id) DO UPDATE SET role = 'owner';
CREATE OR REPLACE FUNCTION public.has_role(role_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.staff_roles sr
      WHERE sr.user_id = auth.uid() AND sr.role = role_name
    ) OR (
      role_name = 'admin' AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    ) OR (
      role_name = 'user' AND NOT EXISTS (
        SELECT 1 FROM public.staff_roles sr WHERE sr.user_id = auth.uid()
      ) AND NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    )
  );
$$;
REVOKE ALL ON FUNCTION public.has_role(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(TEXT) TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.staff_roles sr WHERE sr.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
    )
  );
$$;
REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;
CREATE OR REPLACE FUNCTION public.has_permission(permission_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.staff_roles sr
      WHERE sr.user_id = auth.uid() AND CASE sr.role
        WHEN 'owner' THEN TRUE
        WHEN 'admin' THEN permission_name <> 'staff.owner' OR NOT EXISTS (
          SELECT 1 FROM public.staff_roles owner_role
          WHERE owner_role.role = 'owner'
        )
        WHEN 'moderator' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'content.read', 'content.moderate',
          'reports.read', 'reports.reply'
        ])
        WHEN 'support' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'users.read', 'tickets.read', 'tickets.manage'
        ])
        WHEN 'finance' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'finance.read', 'finance.review'
        ])
        WHEN 'content' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'content.read', 'content.moderate',
          'announcements.manage'
        ])
        ELSE FALSE
      END
    ) OR (
      permission_name <> 'staff.owner' AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    )
  );
$$;
REVOKE ALL ON FUNCTION public.has_permission(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.has_role('admin') OR public.has_role('owner');
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
DROP POLICY IF EXISTS staff_roles_read ON public.staff_roles;
CREATE POLICY staff_roles_read ON public.staff_roles
  FOR SELECT USING (public.has_permission('staff.read'));
REVOKE INSERT, UPDATE, DELETE ON public.staff_roles FROM anon, authenticated;
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
UPDATE public.transactions SET created_by = user_id
WHERE created_by IS NULL AND user_id IS NOT NULL;
DROP TRIGGER IF EXISTS set_transaction_actor ON public.transactions;
CREATE OR REPLACE FUNCTION public.set_transaction_actor()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.created_by IS NULL THEN
    NEW.created_by := COALESCE(auth.uid(), NEW.user_id);
  END IF;
  IF NEW.created_by IS NULL THEN
    RAISE EXCEPTION 'Transaction actor is required' USING ERRCODE = '23502';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER set_transaction_actor
  BEFORE INSERT ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.set_transaction_actor();
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check
  CHECK (type IN ('topup', 'p2p', 'redpacket', 'merchant', 'withdraw', 'bill', 'request'));
DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
DROP POLICY IF EXISTS transactions_own ON public.transactions;
DROP POLICY IF EXISTS transactions_read_own_or_finance ON public.transactions;
CREATE POLICY transactions_read_own_or_finance ON public.transactions
  FOR SELECT USING (
    user_id = auth.uid() OR public.has_permission('finance.read')
  );
REVOKE INSERT, UPDATE, DELETE ON public.transactions FROM anon, authenticated;
DROP POLICY IF EXISTS wallets_own ON public.wallets;
DROP POLICY IF EXISTS wallets_select_own ON public.wallets;
CREATE POLICY wallets_select_own ON public.wallets
  FOR SELECT USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.wallets FROM anon, authenticated;
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS staff_reply TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
DROP POLICY IF EXISTS reports_select_own ON public.reports;
DROP POLICY IF EXISTS reports_select_own_or_staff ON public.reports;
CREATE POLICY reports_select_own_or_staff ON public.reports
  FOR SELECT USING (
    reporter_id = auth.uid() OR public.has_permission('reports.read')
  );
REVOKE UPDATE, DELETE ON public.reports FROM anon, authenticated;
CREATE TABLE IF NOT EXISTS public.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject TEXT NOT NULL CHECK (length(trim(subject)) BETWEEN 1 AND 160),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'resolved')),
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_tickets_status_updated
  ON public.tickets (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_user_created
  ON public.tickets (user_id, created_at DESC);
DROP POLICY IF EXISTS tickets_user_or_staff_read ON public.tickets;
CREATE POLICY tickets_user_or_staff_read ON public.tickets
  FOR SELECT USING (
    user_id = auth.uid() OR public.has_permission('tickets.read')
  );
DROP POLICY IF EXISTS tickets_user_create ON public.tickets;
CREATE POLICY tickets_user_create ON public.tickets
  FOR INSERT WITH CHECK (user_id = auth.uid());
REVOKE UPDATE, DELETE ON public.tickets FROM anon, authenticated;
GRANT SELECT, INSERT ON public.tickets TO authenticated;
CREATE TABLE IF NOT EXISTS public.ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(trim(body)) BETWEEN 1 AND 5000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_created
  ON public.ticket_messages (ticket_id, created_at);
DROP POLICY IF EXISTS ticket_messages_read ON public.ticket_messages;
CREATE POLICY ticket_messages_read ON public.ticket_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_id AND t.user_id = auth.uid()
    ) OR public.has_permission('tickets.read')
  );
DROP POLICY IF EXISTS ticket_messages_user_create ON public.ticket_messages;
CREATE POLICY ticket_messages_user_create ON public.ticket_messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_id AND t.user_id = auth.uid()
    )
  );
REVOKE UPDATE, DELETE ON public.ticket_messages FROM anon, authenticated;
GRANT SELECT, INSERT ON public.ticket_messages TO authenticated;
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 160),
  message TEXT NOT NULL CHECK (length(trim(message)) BETWEEN 1 AND 5000),
  audience TEXT NOT NULL DEFAULT 'all'
    CHECK (audience IN ('all', 'user', 'owner', 'admin', 'moderator', 'support', 'finance', 'content')),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_announcements_published
  ON public.announcements (published_at DESC) WHERE status = 'published';
DROP POLICY IF EXISTS announcements_public_read ON public.announcements;
CREATE POLICY announcements_public_read ON public.announcements
  FOR SELECT USING (
    (status = 'published' AND auth.uid() IS NOT NULL AND (
      audience = 'all' OR public.has_role(audience)
    )) OR public.has_permission('announcements.manage')
  );
REVOKE INSERT, UPDATE, DELETE ON public.announcements FROM anon, authenticated;
ALTER TABLE public.channel_posts
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.oa_posts
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
DROP POLICY IF EXISTS moments_read ON public.moments;
CREATE POLICY moments_read ON public.moments
  FOR SELECT USING (public.can_view_moment(id) AND deleted_at IS NULL);
DROP POLICY IF EXISTS messages_select_member ON public.messages;
CREATE POLICY messages_select_member ON public.messages
  FOR SELECT USING (
    public.is_conversation_member(conversation_id, auth.uid())
    AND deleted_at IS NULL
  );
DROP POLICY IF EXISTS channel_posts_read ON public.channel_posts;
CREATE POLICY channel_posts_read ON public.channel_posts
  FOR SELECT USING (deleted_at IS NULL);
DROP POLICY IF EXISTS oa_posts_read ON public.oa_posts;
CREATE POLICY oa_posts_read ON public.oa_posts
  FOR SELECT USING (deleted_at IS NULL);
CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_subject TEXT,
  p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF length(trim(p_subject)) NOT BETWEEN 1 AND 160
     OR length(trim(p_message)) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Subject and message are required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.tickets (user_id, subject)
  VALUES (auth.uid(), trim(p_subject))
  RETURNING id INTO v_ticket;
  INSERT INTO public.ticket_messages (ticket_id, sender_id, body)
  VALUES (v_ticket, auth.uid(), trim(p_message));
  RETURN v_ticket;
END;
$$;
REVOKE ALL ON FUNCTION public.create_support_ticket(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_support_ticket(TEXT, TEXT) TO authenticated;
CREATE OR REPLACE FUNCTION public.reply_support_ticket(
  p_ticket UUID,
  p_message TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.tickets
    WHERE id = p_ticket AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ticket not found' USING ERRCODE = '42501';
  END IF;
  IF length(trim(p_message)) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Message cannot be empty' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.ticket_messages (ticket_id, sender_id, body)
  VALUES (p_ticket, auth.uid(), trim(p_message));
  UPDATE public.tickets SET status = 'open', updated_at = NOW()
  WHERE id = p_ticket AND user_id = auth.uid();
END;
$$;
REVOKE ALL ON FUNCTION public.reply_support_ticket(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reply_support_ticket(UUID, TEXT) TO authenticated;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS feature_flags_read ON public.feature_flags;
CREATE POLICY feature_flags_read ON public.feature_flags
  FOR SELECT USING (TRUE);
REVOKE INSERT, UPDATE, DELETE ON public.feature_flags FROM anon, authenticated;
INSERT INTO public.feature_flags (key, enabled, description, rollout_percent)
VALUES ('maintenance_mode', FALSE, 'Temporarily restrict app access', 100)
ON CONFLICT (key) DO NOTHING;
DROP POLICY IF EXISTS audit_log_staff_read ON public.audit_log;
CREATE POLICY audit_log_staff_read ON public.audit_log
  FOR SELECT USING (public.has_permission('audit.read'));
REVOKE INSERT, UPDATE, DELETE ON public.audit_log FROM anon, authenticated;
CREATE OR REPLACE FUNCTION public.admin_review_transaction(
  p_transaction_id UUID,
  p_approve BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_txn public.transactions;
  v_balance BIGINT;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission('finance.review') THEN
    RAISE EXCEPTION 'Finance permission required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_txn FROM public.transactions
  WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND OR v_txn.status <> 'pending' THEN
    RAISE EXCEPTION 'Pending transaction not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_txn.type NOT IN ('topup', 'bill') OR v_txn.provider_ref IS NULL THEN
    RAISE EXCEPTION 'A verified provider reference is required' USING ERRCODE = '22023';
  END IF;
  IF p_approve THEN
    INSERT INTO public.wallets (user_id) VALUES (v_txn.user_id)
    ON CONFLICT (user_id) DO NOTHING;
    PERFORM 1 FROM public.wallets WHERE user_id = v_txn.user_id FOR UPDATE;
    IF NOT EXISTS (
      SELECT 1 FROM public.wallets
      WHERE user_id = v_txn.user_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'Wallet is not active' USING ERRCODE = '42501';
    END IF;
    IF v_txn.type = 'bill' THEN
      SELECT COALESCE(SUM(
        CASE WHEN direction = 'credit' THEN amount_minor ELSE -amount_minor END
      ), 0)::BIGINT INTO v_balance
      FROM public.ledger_entries WHERE account = v_txn.user_id::TEXT;
      IF v_balance < v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0) THEN
        RAISE EXCEPTION 'Insufficient balance' USING ERRCODE = '22003';
      END IF;
      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn.id, v_txn.user_id::TEXT, 'debit', v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0)),
        (v_txn.id, 'system:bill', 'credit', v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0));
    ELSE
      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn.id, 'system:topup', 'debit', v_txn.amount_minor),
        (v_txn.id, v_txn.user_id::TEXT, 'credit', v_txn.amount_minor);
    END IF;
    UPDATE public.transactions SET status = 'success', updated_at = NOW()
    WHERE id = v_txn.id;
  ELSE
    UPDATE public.transactions SET status = 'failed', updated_at = NOW()
    WHERE id = v_txn.id;
  END IF;
  INSERT INTO public.audit_log (actor_id, action, target_type, target_id, metadata)
  VALUES (
    auth.uid(),
    CASE WHEN p_approve THEN 'finance.transaction.approved' ELSE 'finance.transaction.rejected' END,
    'transaction', v_txn.id::TEXT,
    jsonb_build_object('type', v_txn.type, 'amount_minor', v_txn.amount_minor)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_review_transaction(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_review_transaction(UUID, BOOLEAN) TO authenticated;
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT,
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','followers')),
  is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
  hidden_by UUID REFERENCES auth.users(id),
  hidden_at TIMESTAMPTZ,
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  like_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('image','video')),
  storage_path TEXT,
  width INTEGER,
  height INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  followee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL DEFAULT 'like' CHECK (reaction_type IN ('like')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS posts_select ON public.posts;
CREATE POLICY posts_select ON public.posts
  FOR SELECT USING (
    deleted_at IS NULL AND is_hidden = FALSE AND (
      author_id = auth.uid() OR
      visibility = 'public' OR
      (visibility = 'followers' AND EXISTS (
        SELECT 1 FROM public.follows f WHERE f.follower_id = auth.uid() AND f.followee_id = posts.author_id
      ))
    )
  );
DROP POLICY IF EXISTS posts_insert_own ON public.posts;
CREATE POLICY posts_insert_own ON public.posts
  FOR INSERT WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS posts_update_own ON public.posts;
CREATE POLICY posts_update_own ON public.posts
  FOR UPDATE USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS posts_delete_own ON public.posts;
CREATE POLICY posts_delete_own ON public.posts
  FOR DELETE USING (author_id = auth.uid());
DROP POLICY IF EXISTS post_media_select ON public.post_media;
CREATE POLICY post_media_select ON public.post_media
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_media.post_id
        AND p.deleted_at IS NULL
        AND p.is_hidden = FALSE
        AND (
          p.author_id = auth.uid() OR
          p.visibility = 'public' OR
          (p.visibility = 'followers' AND EXISTS (
            SELECT 1 FROM public.follows f WHERE f.follower_id = auth.uid() AND f.followee_id = p.author_id
          ))
        )
    )
  );
DROP POLICY IF EXISTS post_media_insert_own ON public.post_media;
CREATE POLICY post_media_insert_own ON public.post_media
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_media.post_id AND p.author_id = auth.uid())
  );
DROP POLICY IF EXISTS post_media_delete_own ON public.post_media;
CREATE POLICY post_media_delete_own ON public.post_media
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_media.post_id AND p.author_id = auth.uid())
  );
DROP POLICY IF EXISTS follows_select ON public.follows;
CREATE POLICY follows_select ON public.follows
  FOR SELECT USING (follower_id = auth.uid() OR followee_id = auth.uid());
DROP POLICY IF EXISTS follows_insert_own ON public.follows;
CREATE POLICY follows_insert_own ON public.follows
  FOR INSERT WITH CHECK (follower_id = auth.uid());
DROP POLICY IF EXISTS follows_delete_own ON public.follows;
CREATE POLICY follows_delete_own ON public.follows
  FOR DELETE USING (follower_id = auth.uid());
DROP POLICY IF EXISTS post_reactions_select ON public.post_reactions;
CREATE POLICY post_reactions_select ON public.post_reactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_reactions.post_id
        AND p.deleted_at IS NULL
        AND p.is_hidden = FALSE
    )
  );
DROP POLICY IF EXISTS post_reactions_insert_own ON public.post_reactions;
CREATE POLICY post_reactions_insert_own ON public.post_reactions
  FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS post_reactions_delete_own ON public.post_reactions;
CREATE POLICY post_reactions_delete_own ON public.post_reactions
  FOR DELETE USING (user_id = auth.uid());
DROP POLICY IF EXISTS post_comments_select ON public.post_comments;
CREATE POLICY post_comments_select ON public.post_comments
  FOR SELECT USING (
    deleted_at IS NULL AND EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_comments.post_id
        AND p.deleted_at IS NULL
        AND p.is_hidden = FALSE
    )
  );
DROP POLICY IF EXISTS post_comments_insert_own ON public.post_comments;
CREATE POLICY post_comments_insert_own ON public.post_comments
  FOR INSERT WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS post_comments_update_own ON public.post_comments;
CREATE POLICY post_comments_update_own ON public.post_comments
  FOR UPDATE USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS post_comments_delete_own ON public.post_comments;
CREATE POLICY post_comments_delete_own ON public.post_comments
  FOR DELETE USING (author_id = auth.uid());
CREATE OR REPLACE FUNCTION public.increment_post_like_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.posts SET like_count = like_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION public.decrement_post_like_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.posts SET like_count = GREATEST(like_count - 1, 0), updated_at = NOW() WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$;
CREATE OR REPLACE FUNCTION public.increment_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.posts SET comment_count = comment_count + 1, updated_at = NOW() WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION public.decrement_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.posts SET comment_count = GREATEST(comment_count - 1, 0), updated_at = NOW() WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$;
DROP TRIGGER IF EXISTS trg_post_reactions_like_insert ON public.post_reactions;
CREATE TRIGGER trg_post_reactions_like_insert
  AFTER INSERT ON public.post_reactions
  FOR EACH ROW EXECUTE FUNCTION public.increment_post_like_count();
DROP TRIGGER IF EXISTS trg_post_reactions_like_delete ON public.post_reactions;
CREATE TRIGGER trg_post_reactions_like_delete
  AFTER DELETE ON public.post_reactions
  FOR EACH ROW EXECUTE FUNCTION public.decrement_post_like_count();
DROP TRIGGER IF EXISTS trg_post_comments_insert ON public.post_comments;
CREATE TRIGGER trg_post_comments_insert
  AFTER INSERT ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.increment_post_comment_count();
DROP TRIGGER IF EXISTS trg_post_comments_delete ON public.post_comments;
CREATE TRIGGER trg_post_comments_delete
  AFTER DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.decrement_post_comment_count();
INSERT INTO storage.buckets (id, name, public)
VALUES ('posts', 'posts', true)
ON CONFLICT (id) DO NOTHING;
DROP POLICY IF EXISTS posts_storage_insert ON storage.objects;
CREATE POLICY posts_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'posts' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );
DROP POLICY IF EXISTS posts_storage_select ON storage.objects;
CREATE POLICY posts_storage_select ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'posts');
DROP POLICY IF EXISTS posts_storage_delete_own ON storage.objects;
CREATE POLICY posts_storage_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'posts' AND
    owner_id = auth.uid()
  );
