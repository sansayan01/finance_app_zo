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
