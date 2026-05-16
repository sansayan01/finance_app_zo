-- Fix loan deletion issues
-- This ensures proper DELETE policies and cascading deletes

-- 1. Ensure DELETE policy exists for loans
DROP POLICY IF EXISTS org_delete ON public.loans;
CREATE POLICY org_delete ON public.loans 
FOR DELETE 
USING (org_id = public.get_user_org_id());

-- 2. Ensure DELETE policy exists for emi_schedule
DROP POLICY IF EXISTS org_delete ON public.emi_schedule;
CREATE POLICY org_delete ON public.emi_schedule 
FOR DELETE 
USING (org_id = public.get_user_org_id());

-- 3. Ensure DELETE policy exists for transactions
DROP POLICY IF EXISTS org_delete ON public.transactions;
CREATE POLICY org_delete ON public.transactions 
FOR DELETE 
USING (org_id = public.get_user_org_id());

-- 4. Add ON DELETE CASCADE to emi_schedule foreign key
ALTER TABLE public.emi_schedule 
DROP CONSTRAINT IF EXISTS emi_schedule_loan_id_fkey;
ALTER TABLE public.emi_schedule 
ADD CONSTRAINT emi_schedule_loan_id_fkey 
FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;

-- 5. Add ON DELETE CASCADE to transactions foreign key
ALTER TABLE public.transactions 
DROP CONSTRAINT IF EXISTS transactions_loan_id_fkey;
ALTER TABLE public.transactions 
ADD CONSTRAINT transactions_loan_id_fkey 
FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;

-- 6. Create a helper function to delete loans safely
CREATE OR REPLACE FUNCTION public.delete_loan_safely(p_loan_id UUID, p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted BOOLEAN := FALSE;
BEGIN
  -- Delete transactions first
  DELETE FROM public.transactions WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Delete EMI schedules
  DELETE FROM public.emi_schedule WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Set loan_id to NULL in collections (ON DELETE SET NULL)
  UPDATE public.collections SET loan_id = NULL WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Delete the loan
  DELETE FROM public.loans WHERE id = p_loan_id AND org_id = p_org_id;
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  
  RETURN v_deleted > 0;
END;
$$;
