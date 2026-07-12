-- Expand numeric precision for loan product fields
-- Before: NUMERIC(5,2) → max 999.99 (caused "numeric field overflow" on save)
-- After:  NUMERIC(8,4) → max 99999.9999

ALTER TABLE loan_products
  ALTER COLUMN interest_rate TYPE NUMERIC(8,4),
  ALTER COLUMN late_penalty_pct TYPE NUMERIC(8,4);
