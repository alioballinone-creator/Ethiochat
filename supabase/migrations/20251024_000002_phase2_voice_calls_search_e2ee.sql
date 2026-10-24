-- Phase 2: voice notes, calls, search prep, E2EE keys

-- Add fields to messages for voice/media metadata
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_duration_ms INTEGER;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_waveform JSONB;

-- Prekeys for E2EE (public only)
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

-- One-time prekeys
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

-- Signed prekey
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

-- Call sessions
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

-- Call participants (for groups)
CREATE TABLE IF NOT EXISTS public.call_participants (
  call_id UUID NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  PRIMARY KEY (call_id, user_id)
);

-- FTS5 for message search (content stored separately)
CREATE TABLE IF NOT EXISTS public.message_search (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL,
  content_tsv TSVECTOR
);

CREATE INDEX IF NOT EXISTS idx_message_search_tsv ON public.message_search USING GIN (content_tsv);
CREATE INDEX IF NOT EXISTS idx_calls_conv ON public.calls (conversation_id, created_at DESC);

-- RLS
ALTER TABLE public.prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onetime_prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signed_prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_search ENABLE ROW LEVEL SECURITY;

-- Prekeys: users can read others' public prekeys for key exchange, manage own
CREATE POLICY prekeys_select ON public.prekeys FOR SELECT USING (true);
CREATE POLICY prekeys_manage_own ON public.prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY onetime_prekeys_select ON public.onetime_prekeys FOR SELECT USING (true);
CREATE POLICY onetime_prekeys_manage_own ON public.onetime_prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY signed_prekeys_select ON public.signed_prekeys FOR SELECT USING (true);
CREATE POLICY signed_prekeys_manage_own ON public.signed_prekeys FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Calls
CREATE POLICY calls_select_member ON public.calls FOR SELECT USING (
  caller_id = auth.uid() OR callee_id = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = calls.conversation_id AND cm.user_id = auth.uid())
);
CREATE POLICY calls_insert ON public.calls FOR INSERT WITH CHECK (caller_id = auth.uid());

CREATE POLICY call_participants_all ON public.call_participants FOR ALL USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.calls c WHERE c.id = call_id AND c.caller_id = auth.uid())
) WITH CHECK (user_id = auth.uid());
