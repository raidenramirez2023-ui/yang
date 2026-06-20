-- Add address column to users table for customer location tracking
-- This will help gather data on which locations frequently dine at Yang Chow

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS address TEXT;

-- Add comment to explain the purpose
COMMENT ON COLUMN users.address IS 'Customer address/location for analytics and tracking frequent dining locations';
