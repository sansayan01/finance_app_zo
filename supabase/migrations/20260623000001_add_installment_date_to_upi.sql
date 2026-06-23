-- Migration: Add installment_date column to upi_payment_requests table
ALTER TABLE public.upi_payment_requests
    ADD COLUMN IF NOT EXISTS installment_date DATE;
