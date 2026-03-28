-- Add expiration_date column to announcements table
ALTER TABLE public.announcements 
ADD COLUMN expiration_date TIMESTAMP WITH TIME ZONE;

-- Update existing announcements to have a default expiration (7 days from now)
UPDATE public.announcements 
SET expiration_date = created_at + INTERVAL '7 days' 
WHERE expiration_date IS NULL;

-- Create a function to automatically expire announcements based on event schedules
CREATE OR REPLACE FUNCTION expire_announcements_based_on_events()
RETURNS TRIGGER AS $$
BEGIN
    -- When a reservation is marked as completed or its event date passes,
    -- automatically expire related announcements
    IF NEW.status = 'completed' OR 
       (NEW.event_date <= NOW() AND NEW.status = 'confirmed') THEN
        UPDATE public.announcements 
        SET is_active = false 
        WHERE title ILIKE '%' || NEW.event_type || '%' 
           OR content ILIKE '%' || NEW.event_type || '%';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically expire announcements
DROP TRIGGER IF EXISTS auto_expire_announcements ON public.reservations;
CREATE TRIGGER auto_expire_announcements
    AFTER UPDATE ON public.reservations
    FOR EACH ROW
    EXECUTE FUNCTION expire_announcements_based_on_events();

-- Create a scheduled function to check and expire announcements daily
CREATE OR REPLACE FUNCTION daily_announcement_cleanup()
RETURNS void AS $$
BEGIN
    -- Deactivate announcements that have passed their expiration date
    UPDATE public.announcements 
    SET is_active = false 
    WHERE is_active = true 
      AND expiration_date <= NOW();
      
    -- Deactivate announcements for events that have ended
    UPDATE public.announcements 
    SET is_active = false 
    WHERE is_active = true 
      AND EXISTS (
        SELECT 1 FROM public.reservations 
        WHERE event_date <= NOW() 
          AND status = 'completed'
          AND (announcements.title ILIKE '%' || reservations.event_type || '%' 
               OR announcements.content ILIKE '%' || reservations.event_type || '%')
      );
END;
$$ LANGUAGE plpgsql;

-- Note: You'll need to set up a cron job or use pg_cron extension to run daily_announcement_cleanup() daily
