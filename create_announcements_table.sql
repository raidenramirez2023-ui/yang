-- Create the announcements table
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Turn on Row Level Security
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active announcements
CREATE POLICY "Allow public read access" ON public.announcements
    FOR SELECT
    USING (is_active = true);

-- Allow authenticated users (who have valid roles) to manage announcements.
-- You can tighten this policy later if needed to restrict to strictly "admin" role.
CREATE POLICY "Allow authenticated full access" ON public.announcements
    FOR ALL
    USING (auth.role() = 'authenticated');
