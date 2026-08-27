-- Revert 'kevindummy' reservation back to Outstanding Balance (deposit_paid)

UPDATE reservations
SET 
  payment_status = 'deposit_paid',
  remaining_balance = COALESCE(total_price, 0) - COALESCE(deposit_amount, 0),
  payment_amount = COALESCE(deposit_amount, payment_amount),
  status = 'confirmed',
  updated_at = NOW()
WHERE 
  customer_name ILIKE '%kevindummy%'
  OR customer_email ILIKE '%kevindummy%';
