-- Storage bucket for post media
INSERT INTO storage.buckets (id, name, public)
VALUES ('posts', 'posts', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload to their own folder
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
