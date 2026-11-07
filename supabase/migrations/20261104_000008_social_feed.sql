-- Social feed: posts, media, comments, reactions, follows

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

-- Posts: users can read public posts or their own; followers can read followers-only posts of people they follow
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

-- post_media follow post visibility roughly
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

-- follows
DROP POLICY IF EXISTS follows_select ON public.follows;
CREATE POLICY follows_select ON public.follows
  FOR SELECT USING (follower_id = auth.uid() OR followee_id = auth.uid());

DROP POLICY IF EXISTS follows_insert_own ON public.follows;
CREATE POLICY follows_insert_own ON public.follows
  FOR INSERT WITH CHECK (follower_id = auth.uid());

DROP POLICY IF EXISTS follows_delete_own ON public.follows;
CREATE POLICY follows_delete_own ON public.follows
  FOR DELETE USING (follower_id = auth.uid());

-- reactions
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

-- comments
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

-- Functions to update counters
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
