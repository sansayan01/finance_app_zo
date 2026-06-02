-- =====================================================
-- CUSTOMER PORTAL REBUILD - Migration
-- Uses existing members.profile_id -> profiles.id chain
-- Creates customer RLS policies, cleans up dead tables
-- =====================================================

-- 1. Helper function: get member_id for current auth user
-- Chain: auth.uid() -> profiles.user_id -> profiles.id -> members.profile_id
CREATE OR REPLACE FUNCTION public.get_member_id_for_auth()
RETURNS UUID AS $$
  SELECT m.id FROM public.members m
  JOIN public.profiles p ON p.id = m.profile_id
  WHERE p.user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 2. Customer-scoped RLS policies on core tables

-- Loans: customers can read their own loans
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'customer_read_own_loans'
  ) THEN
    CREATE POLICY "customer_read_own_loans" ON public.loans
      FOR SELECT USING (
        member_id IN (
          SELECT m.id FROM public.members m
          JOIN public.profiles p ON p.id = m.profile_id
          WHERE p.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- EMI Schedule: customers can read their own EMIs
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'customer_read_own_emi_schedule'
  ) THEN
    CREATE POLICY "customer_read_own_emi_schedule" ON public.emi_schedule
      FOR SELECT USING (
        member_id IN (
          SELECT m.id FROM public.members m
          JOIN public.profiles p ON p.id = m.profile_id
          WHERE p.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Savings Plans: customers can read their own savings
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'customer_read_own_savings'
  ) THEN
    CREATE POLICY "customer_read_own_savings" ON public.savings_plans
      FOR SELECT USING (
        member_id IN (
          SELECT m.id FROM public.members m
          JOIN public.profiles p ON p.id = m.profile_id
          WHERE p.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Transactions: customers can read their own transactions
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'customer_read_own_transactions'
  ) THEN
    CREATE POLICY "customer_read_own_transactions" ON public.transactions
      FOR SELECT USING (
        member_id IN (
          SELECT m.id FROM public.members m
          JOIN public.profiles p ON p.id = m.profile_id
          WHERE p.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- 3. Fix customer_notifications RLS (use profiles lookup instead of direct auth.uid())
DROP POLICY IF EXISTS "customers_own_notifications" ON public.customer_notifications;
CREATE POLICY "customers_own_notifications" ON public.customer_notifications
  FOR ALL USING (
    customer_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

-- 4. Fix customer_support_tickets RLS
DROP POLICY IF EXISTS "customers_own_tickets" ON public.customer_support_tickets;
CREATE POLICY "customers_own_tickets" ON public.customer_support_tickets
  FOR ALL USING (
    customer_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

-- 5. Fix customer_ticket_messages RLS
DROP POLICY IF EXISTS "customers_own_ticket_messages" ON public.customer_ticket_messages;
CREATE POLICY "customers_own_ticket_messages" ON public.customer_ticket_messages
  FOR ALL USING (
    ticket_id IN (
      SELECT id FROM public.customer_support_tickets
      WHERE customer_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    )
  );

-- 6. Fix customer_feedback RLS
DROP POLICY IF EXISTS "customers_own_feedback" ON public.customer_feedback;
CREATE POLICY "customers_own_feedback" ON public.customer_feedback
  FOR ALL USING (
    customer_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

-- 7. Drop dead tables (not needed for view-only MVP)
DROP TABLE IF EXISTS public.customer_app_sessions CASCADE;
DROP TABLE IF EXISTS public.customer_payment_requests CASCADE;

-- 8. Add read policy for members (customers can read their own member record)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'customer_read_own_member'
  ) THEN
    CREATE POLICY "customer_read_own_member" ON public.members
      FOR SELECT USING (
        profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
      );
  END IF;
END $$;

-- 9. Atomic update_member_profile RPC: updates members + profiles in one tx
CREATE OR REPLACE FUNCTION public.update_member_profile(
    p_member_id UUID,
    p_org_id UUID,
    p_data JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID;
    v_profile_sync JSONB := '{}'::JSONB;
    v_member_data JSONB := '{}'::JSONB;
    v_allowed TEXT[] := ARRAY[
        'full_name', 'father_name', 'phone', 'email',
        'area', 'village', 'address', 'aadhar_number', 'pan_number',
        'date_of_birth', 'gender', 'occupation', 'monthly_income'
    ];
    v_key TEXT;
BEGIN
    -- Filter incoming data to only allowed fields
    FOR v_key IN SELECT jsonb_object_keys(p_data) LOOP
        IF v_key = ANY(v_allowed) THEN
            v_member_data := v_member_data || jsonb_build_object(v_key, p_data->v_key);
        END IF;
    END LOOP;

    IF v_member_data = '{}'::JSONB THEN
        RETURN TRUE;
    END IF;

    -- Lock member row and read profile_id atomically
    SELECT profile_id INTO v_profile_id
    FROM public.members
    WHERE id = p_member_id AND org_id = p_org_id
    FOR UPDATE;

    -- Compose profile-sync payload (full_name, phone, email)
    IF v_profile_id IS NOT NULL THEN
        IF v_member_data ? 'full_name' THEN
            v_profile_sync := v_profile_sync || jsonb_build_object('full_name', v_member_data->'full_name');
        END IF;
        IF v_member_data ? 'phone' THEN
            v_profile_sync := v_profile_sync || jsonb_build_object('phone', v_member_data->'phone');
        END IF;
        IF v_member_data ? 'email' THEN
            v_profile_sync := v_profile_sync || jsonb_build_object('email', v_member_data->'email');
        END IF;
    END IF;

    -- Always bump updated_at
    UPDATE public.members
    SET updated_at = NOW()
    WHERE id = p_member_id AND org_id = p_org_id;

    -- Apply member field updates via dynamic SQL built from JSONB keys
    EXECUTE format(
        'UPDATE public.members SET %s WHERE id = $1 AND org_id = $2',
        (
            SELECT string_agg(format('%I = $3->>%L', key, key), ', ')
            FROM jsonb_object_keys(v_member_data) AS key
        )
    ) USING p_member_id, p_org_id, v_member_data;

    -- Apply profile sync fields in the same transaction
    IF v_profile_sync != '{}'::JSONB AND v_profile_id IS NOT NULL THEN
        EXECUTE format(
            'UPDATE public.profiles SET %s WHERE id = $1',
            (
                SELECT string_agg(format('%I = $2->>%L', key, key), ', ')
                FROM jsonb_object_keys(v_profile_sync) AS key
            )
        ) USING v_profile_id, v_profile_sync;
    END IF;

    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_member_profile(UUID, UUID, JSONB) TO authenticated;

-- 10. customer_notification_preferences table for server-side notification sync
CREATE TABLE IF NOT EXISTS public.customer_notification_preferences (
    customer_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    emi_reminder_3_days BOOLEAN NOT NULL DEFAULT TRUE,
    emi_reminder_1_day BOOLEAN NOT NULL DEFAULT TRUE,
    emi_reminder_on_due BOOLEAN NOT NULL DEFAULT TRUE,
    payment_confirmation BOOLEAN NOT NULL DEFAULT TRUE,
    savings_milestone BOOLEAN NOT NULL DEFAULT TRUE,
    system_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (customer_id)
);

ALTER TABLE public.customer_notification_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "customers_own_notification_prefs" ON public.customer_notification_preferences;
CREATE POLICY "customers_own_notification_prefs" ON public.customer_notification_preferences
    FOR ALL USING (customer_id IN (SELECT id FROM public.members WHERE profile_id = auth.uid()));
