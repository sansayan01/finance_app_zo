-- Migration: Expand product templates to match creation form fields

-- Loan products: add interest_logic and default_principal
ALTER TABLE public.loan_products
  ADD COLUMN IF NOT EXISTS interest_logic TEXT DEFAULT 'reducingBalance'
    CHECK (interest_logic IN ('reducingBalance', 'flat')),
  ADD COLUMN IF NOT EXISTS default_principal DECIMAL(12,2);

-- Savings products: add default_installment and default_maturity_amount
ALTER TABLE public.savings_products
  ADD COLUMN IF NOT EXISTS default_installment DECIMAL(12,2),
  ADD COLUMN IF NOT EXISTS default_maturity_amount DECIMAL(12,2);
