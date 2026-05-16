-- Add status column to emi_schedule for better EMI tracking
-- This allows for more granular status tracking beyond just is_paid boolean

ALTER TABLE public.emi_schedule 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'upcoming' 
CHECK (status IN ('upcoming', 'paid', 'overdue', 'defaulted', 'pendingPayment'));

-- Add payment_mode column for tracking how the EMI was paid
ALTER TABLE public.emi_schedule 
ADD COLUMN IF NOT EXISTS payment_mode TEXT 
CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card'));

-- Add paid_on column for consistency with model expectations
ALTER TABLE public.emi_schedule 
ADD COLUMN IF NOT EXISTS paid_on TIMESTAMP WITH TIME ZONE;

-- Add amount_paid column to track actual amount collected
ALTER TABLE public.emi_schedule 
ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(12,2) DEFAULT 0;

-- Add transaction_id for linking to transaction records
ALTER TABLE public.emi_schedule 
ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES public.transactions(id);

-- Update existing paid EMIs to have proper status
UPDATE public.emi_schedule 
SET status = 'paid', 
    paid_on = paid_date,
    payment_mode = 'cash'
WHERE is_paid = true;

-- Add indexes for new columns
CREATE INDEX IF NOT EXISTS idx_emi_schedule_status ON public.emi_schedule(status);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_payment_mode ON public.emi_schedule(payment_mode);
