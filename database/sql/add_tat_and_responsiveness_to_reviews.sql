-- Add Turnaround Time (TAT) and Responsiveness Rate columns to reviews table
ALTER TABLE IF EXISTS public.reviews 
ADD COLUMN IF NOT EXISTS turnaround_time INT CHECK (turnaround_time >= 1 AND turnaround_time <= 5),
ADD COLUMN IF NOT EXISTS responsiveness_rate INT CHECK (responsiveness_rate >= 1 AND responsiveness_rate <= 5);

COMMENT ON COLUMN public.reviews.turnaround_time IS 'Turnaround Time (TAT) rating 1-5';
COMMENT ON COLUMN public.reviews.responsiveness_rate IS 'Responsiveness Rate rating 1-5';
