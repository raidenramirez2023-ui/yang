-- Run this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

-- Create orders table
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id text NOT NULL,
  customer_name text NOT NULL DEFAULT 'Guest',
  total_amount numeric(12, 2) NOT NULL DEFAULT 0,
  item_count integer NOT NULL DEFAULT 0,
  staff_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  unit_price numeric(12, 2) NOT NULL DEFAULT 0,
  subtotal numeric(12, 2) NOT NULL DEFAULT 0
);

-- Enable Row Level Security
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Allow all operations (for staff/anon access)
CREATE POLICY "Allow all on orders" ON public.orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on order_items" ON public.order_items FOR ALL USING (true) WITH CHECK (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON public.order_items(order_id);
