-- EthioChat Phase 1: Core schema, RLS, and per-conversation sequence
-- uuid PKs, timestamptz, soft deletes, RLS on every table.

-- Required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  ethio_id TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  language TEXT DEFAULT 'en',
  phone_hash TEXT,
  last_seen_at TIMESTAMPTZ,
  privacy JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Devices
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT,
  platform TEXT,
  identity_pubkey BYTEA,
  prekeys JSONB DEFAULT '[]'::jsonb,
  last_active TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Contacts
CREATE TABLE IF NOT EXISTS public.contacts (
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alias TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (owner_id, contact_id)
);

-- Conversations
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('direct','group','channel')),
  title TEXT,
  avatar_url TEXT,
  created_by UUID REFERENCES auth.users(id),
  last_message_id UUID,
  last_message_at TIMESTAMPTZ,
  seq_counter BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Conversation members
CREATE TABLE IF NOT EXISTS public.conversation_members (
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','admin','member')),
  muted_until TIMESTAMPTZ,
  last_read_seq BIGINT DEFAULT 0,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  PRIMARY KEY (conversation_id, user_id)
);

-- Messages (client-generated id for idempotency)
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seq BIGINT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('text','image','voice','video','file','location','contact','sticker','payment','redpacket','system')),
  body TEXT,
  media JSONB,
  reply_to UUID REFERENCES public.messages(id),
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (conversation_id, seq)
);

-- Message receipts
CREATE TABLE IF NOT EXISTS public.message_receipts (
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  PRIMARY KEY (message_id, user_id)
);

-- Per-conversation sequence assignment (gapless, monotonic)
CREATE OR REPLACE FUNCTION public.assign_message_seq()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_assign_message_seq ON public.messages;
CREATE TRIGGER trg_assign_message_seq
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  WHEN (NEW.seq IS NULL)
  EXECUTE FUNCTION public.assign_message_seq();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_conv_seq ON public.messages (conversation_id, seq DESC);
CREATE INDEX IF NOT EXISTS idx_conv_members_user ON public.conversation_members (user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON public.messages (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_receipts_user ON public.message_receipts (user_id);

-- Enable RLS on every table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;

-- Helper: is member of conversation
CREATE OR REPLACE FUNCTION public.is_conversation_member(cid UUID, uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = cid AND user_id = uid AND left_at IS NULL
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Profiles: read self or contacts? Phase 1: user can read/update their own
CREATE POLICY profiles_select_self ON public.profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY profiles_update_self ON public.profiles
  FOR UPDATE USING (id = auth.uid());

CREATE POLICY profiles_insert_self ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- Devices: own only
CREATE POLICY devices_all_own ON public.devices
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Contacts
CREATE POLICY contacts_owner ON public.contacts
  FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- Conversations: members can see
CREATE POLICY conversations_select_member ON public.conversations
  FOR SELECT USING (public.is_conversation_member(id, auth.uid()));

CREATE POLICY conversations_update_creator_or_admin ON public.conversations
  FOR UPDATE USING (
    created_by = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );

-- Members
CREATE POLICY members_select ON public.conversation_members
  FOR SELECT USING (public.is_conversation_member(conversation_id, auth.uid()) OR user_id = auth.uid());

CREATE POLICY members_insert ON public.conversation_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );

CREATE POLICY members_update ON public.conversation_members
  FOR UPDATE USING (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid() AND cm.role IN ('owner','admin')
    )
  );

-- Messages: members only; insert only if sender is self and member
CREATE POLICY messages_select_member ON public.messages
  FOR SELECT USING (public.is_conversation_member(conversation_id, auth.uid()));

CREATE POLICY messages_insert_member ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND public.is_conversation_member(conversation_id, auth.uid())
  );

CREATE POLICY messages_update_sender ON public.messages
  FOR UPDATE USING (sender_id = auth.uid());

-- Receipts
CREATE POLICY receipts_select_member ON public.message_receipts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id, auth.uid())
    )
  );

CREATE POLICY receipts_upsert_self ON public.message_receipts
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
