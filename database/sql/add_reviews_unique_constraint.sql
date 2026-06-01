-- Add unique constraint on customer_email for reviews table
-- This allows upsert operations to work correctly when submitting reviews

-- First, remove any duplicate reviews (keep the most recent one per customer)
DELETE FROM reviews r1
WHERE EXISTS (
  SELECT 1
  FROM reviews r2
  WHERE r2.customer_email = r1.customer_email
    AND r2.created_at > r1.created_at
);

-- Add unique constraint on customer_email
ALTER TABLE reviews
ADD CONSTRAINT reviews_customer_email_unique UNIQUE (customer_email);
