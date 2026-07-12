-- Expand interest_rate precision to support both % and ₹ fixed amount modes
-- Before: NUMERIC(8,4) → max 9999.9999 (overflow on ₹10,000+ fixed amounts)
-- After:  NUMERIC(12,2) → max 999,999,999.99

ALTER TABLE loan_products
  ALTER COLUMN interest_rate TYPE NUMERIC(12,2);
