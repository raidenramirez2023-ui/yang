-- Allow authenticated users to upload images
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'chat_images');

-- Allow authenticated users to update images (if needed)
CREATE POLICY "Allow authenticated updates" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'chat_images');

-- Allow public read access to images
CREATE POLICY "Allow public read access" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'chat_images');

-- Allow authenticated users to read their own images
CREATE POLICY "Allow authenticated read access" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'chat_images');
