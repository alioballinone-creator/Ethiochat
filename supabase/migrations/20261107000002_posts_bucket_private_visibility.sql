-- Phase B: make posts bucket private and enforce visibility via storage policies.
-- Do not edit 000009. Signed URLs are issued by the app for authorized viewers.
UPDATE storage.buckets SET public = false WHERE id = 'posts';

DROP POLICY IF EXISTS posts_storage_select ON storage.objects;
CREATE POLICY posts_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'posts' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (
        SELECT 1
        FROM public.posts p
        JOIN public.post_media pm ON pm.post_id = p.id
        WHERE pm.storage_path = name
          AND p.deleted_at IS NULL
          AND p.is_hidden = FALSE
          AND (
            p.visibility = 'public'
            OR p.author_id = auth.uid()
            OR (p.visibility = 'followers' AND EXISTS (
              SELECT 1 FROM public.follows f
              WHERE f.follower_id = auth.uid() AND f.followee_id = p.author_id
            ))
          )
      )
    )
  );

DROP POLICY IF EXISTS posts_storage_insert ON storage.objects;
CREATE POLICY posts_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'posts' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS posts_storage_delete_own ON storage.objects;
CREATE POLICY posts_storage_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'posts' AND
    owner_id = auth.uid()
  );
