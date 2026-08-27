-- 1. Ensure the column exists
ALTER TABLE public.reservations 
ADD COLUMN IF NOT EXISTS transacted_by TEXT;

-- 2. Update all existing/past reservations that were already confirmed, completed, or handled
UPDATE public.reservations
SET transacted_by = 'admn.pagsanjan@gmail.com'
WHERE transacted_by IS NULL 
   OR transacted_by = '' 
   OR transacted_by LIKE 'Online%';

-- 3. Reload Supabase schema cache
NOTIFY pgrst, 'reload schema';
