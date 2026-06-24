-- Migration script to add transaction_id column to public.collections
-- Run this in your Supabase SQL Editor to fix missing column issues.

-- 1. Add missing transaction_id column referencing public.transactions
ALTER TABLE public.collections 
ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL;

-- 2. Create index for faster matching queries
CREATE INDEX IF NOT EXISTS idx_collections_transaction_id ON public.collections(transaction_id);
