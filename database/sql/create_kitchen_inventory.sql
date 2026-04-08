-- Create kitchen_inventory table
CREATE TABLE IF NOT EXISTS kitchen_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  category TEXT,
  quantity INTEGER NOT NULL DEFAULT 0,
  unit TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE kitchen_inventory ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read kitchen_inventory
CREATE POLICY "Allow authenticated users to read kitchen_inventory"
  ON kitchen_inventory FOR SELECT
  USING (auth.role() = 'authenticated');

-- Allow authenticated users to insert/update kitchen_inventory
CREATE POLICY "Allow authenticated users to insert kitchen_inventory"
  ON kitchen_inventory FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to update kitchen_inventory"
  ON kitchen_inventory FOR UPDATE
  USING (auth.role() = 'authenticated');

-- Comment
COMMENT ON TABLE kitchen_inventory IS 'Stores the stock available in the kitchen side, separate from the main inventory.';
