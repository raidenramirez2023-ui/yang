-- Migration to add table management to Yang Chow Restaurant

-- 1. Create restaurant_tables table
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_number INTEGER UNIQUE NOT NULL,
    capacity INTEGER NOT NULL,
    table_type TEXT DEFAULT 'Regular', -- Regular, Booth, VIP, Outdoor
    status TEXT DEFAULT 'available', -- available, reserved, occupied, cleaning
    x_pos DOUBLE PRECISION DEFAULT 0.0, -- for visual map
    y_pos DOUBLE PRECISION DEFAULT 0.0, -- for visual map
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Add table_id to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS table_id UUID REFERENCES restaurant_tables(id);

-- 3. Add temporary reservation hold table (5-minute lock logic)
CREATE TABLE IF NOT EXISTS table_holds (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_id UUID REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    customer_email TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Sample data for tables (Updated to actual counts: 4x5, 4x6, 4x4, 3x2)
DELETE FROM restaurant_tables;
INSERT INTO restaurant_tables (table_number, capacity, table_type, x_pos, y_pos)
VALUES 
    -- Row 1: 5-Person Tables
    (1, 5, 'Regular', 0.2, 0.15),
    (2, 5, 'Regular', 0.4, 0.15),
    (3, 5, 'Regular', 0.6, 0.15),
    (4, 5, 'Regular', 0.8, 0.15),
    -- Row 2: 6-Person Tables
    (5, 6, 'VIP', 0.2, 0.35),
    (6, 6, 'VIP', 0.4, 0.35),
    (7, 6, 'VIP', 0.6, 0.35),
    (8, 6, 'VIP', 0.8, 0.35),
    -- Row 3: 4-Person Tables
    (9, 4, 'Booth', 0.2, 0.55),
    (10, 4, 'Booth', 0.4, 0.55),
    (11, 4, 'Booth', 0.6, 0.55),
    (12, 4, 'Booth', 0.8, 0.55),
    -- Row 4: 2-Person Tables
    (13, 2, 'Couple', 0.2, 0.75),
    (14, 2, 'Couple', 0.4, 0.75),
    (15, 2, 'Couple', 0.6, 0.75);
