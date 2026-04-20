-- Add image_url and tag columns to announcements table
ALTER TABLE public.announcements 
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT 'Update';

-- Standardize expiration column name if needed
-- Note: add_announcement_expiration.sql already adds expiration_date.
-- If the Dart code was using expires_at, it might have failed if it wasn't in the schema.
-- Let's ensure both or one exists. I'll stick to expiration_date as per the previous migration file.
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='announcements' AND column_name='expiration_date') THEN
        ALTER TABLE public.announcements ADD COLUMN expiration_date TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;
