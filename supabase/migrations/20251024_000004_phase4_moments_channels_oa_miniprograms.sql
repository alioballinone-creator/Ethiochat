-- Phase 4

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

-- RLS
ALTER TABLE public.moments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moment_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.official_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oa_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oa_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mini_programs ENABLE ROW LEVEL SECURITY;

CREATE POLICY moments_read ON public.moments FOR SELECT USING (true);
CREATE POLICY moments_own ON public.moments FOR ALL USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY moment_likes_all ON public.moment_likes FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY moment_comments_all ON public.moment_comments FOR ALL USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY channels_read ON public.channels FOR SELECT USING (true);
CREATE POLICY channel_posts_read ON public.channel_posts FOR SELECT USING (true);
CREATE POLICY oa_read ON public.official_accounts FOR SELECT USING (true);
CREATE POLICY oa_posts_read ON public.oa_posts FOR SELECT USING (true);
CREATE POLICY oa_subs_all ON public.oa_subscriptions FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY miniprograms_read ON public.mini_programs FOR SELECT USING (status = 'approved');
