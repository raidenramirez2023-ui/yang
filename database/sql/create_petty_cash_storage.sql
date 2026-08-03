-- Create storage bucket for petty cash receipts
-- Note: If you get permission errors, create the bucket manually in Supabase Dashboard > Storage
-- Then run only the RLS policies below

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('petty_cash_receipts', 'petty_cash_receipts', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/jpg'])
ON CONFLICT (id) DO NOTHING;

-- Policy: Allow authenticated users to upload receipts
CREATE POLICY "Allow authenticated users to upload receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'petty_cash_receipts'
  AND auth.role() = 'authenticated'
);

-- Policy: Allow authenticated users to view receipts
CREATE POLICY "Allow authenticated users to view receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'petty_cash_receipts'
  AND auth.role() = 'authenticated'
);

-- Policy: Allow admins to delete receipts
CREATE POLICY "Allow admins to delete receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'petty_cash_receipts'
  AND (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  )
);
