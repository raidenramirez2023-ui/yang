-- Add avatar_url column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS users_avatar_url_idx ON users(avatar_url);

-- Verify the updated table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;
