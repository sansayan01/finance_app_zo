-- Migration: Add product_id FK columns to loans and savings_plans
-- Links loan/savings records to their product templates

-- Add product_id to loans
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'loans' AND column_name = 'product_id'
  ) THEN
    ALTER TABLE public.loans ADD COLUMN product_id UUID REFERENCES public.loan_products(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add product_id to savings_plans
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'savings_plans' AND column_name = 'product_id'
  ) THEN
    ALTER TABLE public.savings_plans ADD COLUMN product_id UUID REFERENCES public.savings_products(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_loans_product ON public.loans(product_id);
CREATE INDEX IF NOT EXISTS idx_savings_plans_product ON public.savings_plans(product_id);
