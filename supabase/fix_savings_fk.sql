-- Fix foreign key constraint on the transactions table
-- Currently, the foreign key constraint 'fk_txn_savings' points to the legacy and empty 'savings' table.
-- Since active savings are stored in the 'savings_plans' table, recording a deposit or withdrawal 
-- throws a foreign key violation error (code 23503).
--
-- This script drops the legacy constraint and redirects it to point to the active 'savings_plans' table.

-- 1. Drop the legacy foreign key constraint
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS fk_txn_savings;

-- 2. Add the correct constraint referencing public.savings_plans
ALTER TABLE public.transactions 
ADD CONSTRAINT fk_txn_savings 
FOREIGN KEY (savings_id) REFERENCES public.savings_plans(id) 
ON DELETE SET NULL;
