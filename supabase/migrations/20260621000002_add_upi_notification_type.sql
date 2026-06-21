-- Migration: Add UPI notification type and org_id to staff_notifications
-- 1. Add org_id column so RLS can work for customer-portal inserts
-- 2. Update CHECK constraint to include 'upi' type

-- Add org_id column
ALTER TABLE public.staff_notifications
    ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- Drop old CHECK constraint and add updated one with 'upi'
ALTER TABLE public.staff_notifications
    DROP CONSTRAINT IF EXISTS staff_notifications_type_check;

ALTER TABLE public.staff_notifications
    ADD CONSTRAINT staff_notifications_type_check
    CHECK (type IN ('target', 'overdue', 'sync', 'alert', 'reminder', 'system', 'upi'));

-- Update RLS INSERT policy to allow inserts when org_id matches
DROP POLICY IF EXISTS staff_notifications_insert ON public.staff_notifications;
CREATE POLICY staff_notifications_insert ON public.staff_notifications FOR INSERT
    WITH CHECK (
        org_id = public.get_user_org_id()
        OR staff_id IN (
            SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
        )
    );
