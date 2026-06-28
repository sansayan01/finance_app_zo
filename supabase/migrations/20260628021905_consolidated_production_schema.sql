-- Consolidated production schema snapshot
-- Pulled from production on 2026-06-28
-- This is the single source of truth for the entire database schema




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."accept_invitation"("p_token" "text", "p_full_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_invitation RECORD;
    v_user_id UUID;
    v_org_id UUID;
    v_result JSONB;
BEGIN
    -- Get the invitation
    SELECT * INTO v_invitation
    FROM public.org_invitations
    WHERE token = p_token AND status = 'pending' AND expires_at > now();
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Invalid or expired invitation');
    END IF;
    
    -- Get user_id from auth.users using the email
    -- This is safe because SECURITY DEFINER gives us access
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_invitation.email;
    
    IF v_user_id IS NULL THEN
        -- User doesn't have an account yet - they need to sign up
        RETURN jsonb_build_object(
            'action', 'signup', 
            'email', v_invitation.email, 
            'org_id', v_invitation.org_id, 
            'role', v_invitation.role, 
            'branch_id', v_invitation.branch_id
        );
    END IF;
    
    -- Update the user's profile with the invitation details
    UPDATE public.profiles 
    SET 
        org_id = v_invitation.org_id, 
        role = v_invitation.role, 
        branch_id = v_invitation.branch_id, 
        full_name = COALESCE(p_full_name, full_name)
    WHERE user_id = v_user_id;
    
    -- Mark invitation as accepted
    UPDATE public.org_invitations 
    SET 
        status = 'accepted', 
        accepted_at = now(), 
        accepted_by = v_user_id 
    WHERE id = v_invitation.id;
    
    RETURN jsonb_build_object(
        'action', 'login', 
        'user_id', v_user_id, 
        'org_id', v_invitation.org_id, 
        'role', v_invitation.role
    );
END;
$$;


ALTER FUNCTION "public"."accept_invitation"("p_token" "text", "p_full_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_set_loan_branch_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.branch_id IS NULL THEN
    IF NEW.member_id IS NOT NULL THEN
      SELECT branch_id INTO NEW.branch_id
      FROM public.members
      WHERE id = NEW.member_id;
    ELSIF NEW.customer_id IS NOT NULL THEN
      SELECT branch_id INTO NEW.branch_id
      FROM public.members
      WHERE id = NEW.customer_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_set_loan_branch_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_email_exists"("p_email" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE lower(email) = lower(p_email)
  );
END;
$$;


ALTER FUNCTION "public"."check_email_exists"("p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_setup_complete"() RETURNS TABLE("is_complete" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.branches b
    WHERE b.org_id = (
      SELECT COALESCE(p.org_id, '00000000-0000-0000-0000-000000000001'::uuid)
      FROM public.profiles p WHERE p.user_id = auth.uid() LIMIT 1
    )
  ) OR EXISTS (
    SELECT 1 FROM public.profiles p2
    WHERE p2.org_id = (
      SELECT COALESCE(p3.org_id, '00000000-0000-0000-0000-000000000001'::uuid)
      FROM public.profiles p3 WHERE p3.user_id = auth.uid() LIMIT 1
    )
    AND p2.role IN ('manager', 'collectionAgent')
  );
$$;


ALTER FUNCTION "public"."check_setup_complete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_subscription_limit"("p_org_id" "uuid", "p_limit_type" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_count integer;
  v_limit integer;
BEGIN
  -- Default limits (can be overridden by platform_settings)
  v_limit := CASE p_limit_type
    WHEN 'members' THEN 1000
    WHEN 'loans' THEN 5000
    WHEN 'branches' THEN 50
    WHEN 'staff' THEN 100
    ELSE 999999
  END;

  v_count := CASE p_limit_type
    WHEN 'members' THEN (SELECT COUNT(*) FROM public.members WHERE org_id = p_org_id)
    WHEN 'loans' THEN (SELECT COUNT(*) FROM public.loans WHERE org_id = p_org_id)
    WHEN 'branches' THEN (SELECT COUNT(*) FROM public.branches WHERE org_id = p_org_id)
    WHEN 'staff' THEN (SELECT COUNT(*) FROM public.profiles WHERE org_id = p_org_id AND role IN ('manager', 'collectionAgent'))
    ELSE 0
  END;

  RETURN v_count >= v_limit;
END;
$$;


ALTER FUNCTION "public"."check_subscription_limit"("p_org_id" "uuid", "p_limit_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_invitations"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE public.org_invitations SET status = 'expired' WHERE status = 'pending' AND expires_at < now();
    GET DIAGNOSTICS v_count = ROW_COUNT;
    DELETE FROM public.password_reset_tokens WHERE expires_at < now();
    DELETE FROM public.magic_links WHERE expires_at < now();
    DELETE FROM public.email_verification_tokens WHERE expires_at < now();
    RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_invitations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_locations"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  DELETE FROM public.staff_locations
  WHERE recorded_at < NOW() - INTERVAL '7 days';
$$;


ALTER FUNCTION "public"."cleanup_old_locations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_invitation"("p_org_id" "uuid", "p_email" "text", "p_role" "text", "p_branch_id" "uuid" DEFAULT NULL::"uuid", "p_message" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_invitation_id UUID;
    v_inviter_id UUID;
BEGIN
    SELECT user_id INTO v_inviter_id FROM public.profiles WHERE user_id = auth.uid();
    INSERT INTO public.org_invitations (org_id, email, role, branch_id, invited_by, personal_message)
    VALUES (p_org_id, p_email, p_role, p_branch_id, v_inviter_id, p_message)
    RETURNING id INTO v_invitation_id;
    RETURN v_invitation_id;
END;
$$;


ALTER FUNCTION "public"."create_invitation"("p_org_id" "uuid", "p_email" "text", "p_role" "text", "p_branch_id" "uuid", "p_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_staff_points"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO public.staff_points (staff_id, org_id, total_points)
    VALUES (NEW.id, NEW.org_id, 0)
    ON CONFLICT (staff_id) DO NOTHING;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_staff_points"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_staff_streaks"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ BEGIN INSERT INTO public.staff_streaks (staff_id) VALUES (NEW.id) ON CONFLICT (staff_id) DO NOTHING; RETURN NEW; END; $$;


ALTER FUNCTION "public"."create_staff_streaks"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_staff_wallet"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ BEGIN INSERT INTO public.staff_wallet (staff_id, org_id) VALUES (NEW.id, NEW.org_id) ON CONFLICT (staff_id) DO NOTHING; RETURN NEW; END; $$;


ALTER FUNCTION "public"."create_staff_wallet"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_collection"("p_collection_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_collection RECORD;
    v_org_id UUID;
    v_user_role TEXT;
    v_reverted_count INT := 0;
BEGIN
    -- Get the collection
    SELECT * INTO v_collection FROM public.collections WHERE id = p_collection_id;

    IF v_collection IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Collection not found');
    END IF;

    -- Check that the caller is an executiveAdmin for this org
    v_user_role := public.get_user_role();
    v_org_id := public.get_user_org_id();

    IF v_user_role != 'executiveAdmin' AND v_user_role != 'superAdmin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only executive admin can delete collections');
    END IF;

    IF v_collection.org_id != v_org_id AND v_user_role != 'superAdmin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot delete collection from another organization');
    END IF;

    -- 1. Revert EMI schedule: mark the specific schedule as unpaid if loan_schedule_id exists
    IF v_collection.loan_id IS NOT NULL THEN
        IF v_collection.loan_schedule_id IS NOT NULL THEN
            UPDATE public.emi_schedule
            SET is_paid = false,
                status = 'pending',
                paid_on = NULL,
                paid_date = NULL,
                payment_mode = NULL,
                amount_paid = NULL
            WHERE id = v_collection.loan_schedule_id
              AND is_paid = true;
            GET DIAGNOSTICS v_reverted_count = ROW_COUNT;
        END IF;

        -- If no specific schedule was reverted, revert the most recently paid one
        IF v_reverted_count = 0 THEN
            UPDATE public.emi_schedule
            SET is_paid = false,
                status = 'pending',
                paid_on = NULL,
                paid_date = NULL,
                payment_mode = NULL,
                amount_paid = NULL
            WHERE ctid = (
                SELECT ctid FROM public.emi_schedule
                WHERE loan_id = v_collection.loan_id
                  AND paid_on IS NOT NULL
                  AND is_paid = true
                ORDER BY paid_on DESC
                LIMIT 1
            );
            GET DIAGNOSTICS v_reverted_count = ROW_COUNT;
        END IF;

        -- 2. Revert loan outstanding amount
        UPDATE public.loans
        SET outstanding_amount = outstanding_amount + v_collection.amount_collected,
            outstanding_balance = outstanding_balance + v_collection.amount_collected,
            paid_emis = GREATEST(COALESCE(paid_emis, 0) - v_reverted_count, 0),
            status = CASE WHEN status = 'closed' THEN 'active' ELSE status END
        WHERE id = v_collection.loan_id;
    END IF;

    -- 3. Revert staff wallet (using last_updated, not updated_at)
    IF v_collection.staff_id IS NOT NULL THEN
        UPDATE public.staff_wallet
        SET cash_in_hand = cash_in_hand - v_collection.amount_collected,
            total_collected_today = GREATEST(total_collected_today - v_collection.amount_collected, 0),
            last_updated = now()
        WHERE staff_id = v_collection.staff_id;
    END IF;

    -- 4. Delete related transactions
    DELETE FROM public.transactions
    WHERE loan_id = v_collection.loan_id
      AND amount = v_collection.amount_collected
      AND created_at >= v_collection.created_at - interval '1 minute'
      AND created_at <= v_collection.created_at + interval '1 minute';

    -- 5. Delete the collection itself
    DELETE FROM public.collections WHERE id = p_collection_id;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_id', p_collection_id,
        'reverted_amount', v_collection.amount_collected
    );
END;
$$;


ALTER FUNCTION "public"."delete_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_loan_collection"("p_collection_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_col RECORD;
  v_loan_id UUID;
  v_amount DECIMAL(12,2);
  v_tx_id UUID;
  v_schedule_id UUID;
  v_rec_result JSONB;
BEGIN
  -- 1. Fetch the collection
  SELECT * INTO v_col FROM public.collections WHERE id = p_collection_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Collection not found');
  END IF;

  v_loan_id := v_col.loan_id;
  v_amount := v_col.amount_collected;
  v_schedule_id := v_col.selected_schedule_id;

  -- 2. Unmark the SPECIFIC EMI if selected_schedule_id is known
  IF v_schedule_id IS NOT NULL THEN
    UPDATE public.emi_schedule
    SET
      is_paid = false,
      status = 'pending',
      paid_on = NULL,
      paid_date = NULL,
      payment_mode = NULL,
      amount_paid = 0,
      transaction_id = NULL
    WHERE id = v_schedule_id
      AND is_paid = true;
  ELSE
    -- Fallback: unmark the most recently paid EMI that hasn't been
    -- linked to a DIFFERENT collection via selected_schedule_id
    UPDATE public.emi_schedule
    SET
      is_paid = false,
      status = 'pending',
      paid_on = NULL,
      paid_date = NULL,
      payment_mode = NULL,
      amount_paid = 0,
      transaction_id = NULL
    WHERE id = (
      SELECT es.id
      FROM public.emi_schedule es
      WHERE es.loan_id = v_loan_id
        AND es.is_paid = true
        AND NOT EXISTS (
          SELECT 1 FROM public.collections c
          WHERE c.loan_id = v_loan_id
            AND c.selected_schedule_id = es.id
            AND c.id != p_collection_id
        )
      ORDER BY es.paid_on DESC NULLS LAST, es.emi_number DESC
      LIMIT 1
    );
  END IF;

  -- 3. Find and delete the matching transaction using transaction_id first for precision
  IF v_col.transaction_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = v_col.transaction_id;
  ELSE
    -- Fallback: match by amount but only if no other collection uses this transaction
    SELECT id INTO v_tx_id
    FROM public.transactions
    WHERE loan_id = v_loan_id
      AND amount = v_amount
      AND org_id = v_col.org_id
      AND NOT EXISTS (
        SELECT 1 FROM public.collections c
        WHERE c.transaction_id = public.transactions.id
          AND c.id != p_collection_id
      )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_tx_id IS NOT NULL THEN
      DELETE FROM public.transactions WHERE id = v_tx_id;
    END IF;
  END IF;

  -- 4. Delete the collection
  DELETE FROM public.collections WHERE id = p_collection_id;

  -- 5. Recalculate outstanding from EMI schedule (source of truth)
  SELECT public.recalculate_loan_outstanding(v_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', v_loan_id,
    'restored_amount', v_amount,
    'recalc', v_rec_result
  );
END;
$$;


ALTER FUNCTION "public"."delete_loan_collection"("p_collection_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_loan_safely"("p_loan_id" "uuid", "p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_deleted BOOLEAN := FALSE;
BEGIN
  -- Delete transactions first
  DELETE FROM public.transactions WHERE loan_id = p_loan_id AND org_id = p_org_id;

  -- Nullify both FK references in UPI payment requests
  UPDATE public.upi_payment_requests SET emi_schedule_id = NULL, loan_id = NULL WHERE loan_id = p_loan_id;

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


ALTER FUNCTION "public"."delete_loan_safely"("p_loan_id" "uuid", "p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_savings_safely"("p_savings_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_deleted BOOLEAN := FALSE;
BEGIN
  -- Nullify UPI payment request references
  UPDATE public.upi_payment_requests SET savings_plan_id = NULL WHERE savings_plan_id = p_savings_id;

  -- Delete collection records
  DELETE FROM public.savings_collections WHERE savings_plan_id = p_savings_id;

  -- Delete transactions
  DELETE FROM public.transactions WHERE savings_id = p_savings_id;

  -- Delete the plan
  DELETE FROM public.savings_plans WHERE id = p_savings_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN v_deleted > 0;
END;
$$;


ALTER FUNCTION "public"."delete_savings_safely"("p_savings_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_savings_transaction"("p_transaction_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_tx RECORD;
  v_savings_id UUID;
  v_amount DECIMAL(12,2);
  v_org_id UUID;
  v_member_id UUID;
  v_opening_balance DECIMAL(12,2);
  v_new_balance DECIMAL(12,2);
  v_collection_type TEXT;
  v_start_date DATE;
  v_max_paid_date DATE;
  v_new_next_due DATE;
BEGIN
  -- 1. Fetch the transaction
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
  END IF;

  v_savings_id := v_tx.savings_id;
  v_amount := v_tx.amount;
  v_org_id := v_tx.org_id;
  v_member_id := v_tx.member_id;

  -- 2. Delete matching savings_collections record using transaction_id first for precision
  IF v_savings_id IS NOT NULL THEN
    DELETE FROM public.savings_collections
    WHERE transaction_id = p_transaction_id;

    -- Fallback: if no collection linked by transaction_id, try amount/member match but only ONE record
    IF NOT FOUND THEN
      DELETE FROM public.savings_collections
      WHERE id = (
        SELECT sc.id FROM public.savings_collections sc
        WHERE sc.savings_plan_id = v_savings_id
          AND sc.member_id = v_member_id
          AND (sc.amount_collected = v_amount OR sc.amount_expected = v_amount)
          AND sc.org_id = v_org_id
        LIMIT 1
      );
    END IF;
  END IF;

  -- 3. Delete the transaction
  DELETE FROM public.transactions WHERE id = p_transaction_id;

  -- 4. Recalculate current_amount
  SELECT COALESCE(opening_balance, 0) INTO v_opening_balance
  FROM public.savings_plans WHERE id = v_savings_id;

  SELECT COALESCE(SUM(
    CASE WHEN t.type IN ('savingsDeposit', 'deposit') THEN t.amount
         WHEN t.type IN ('savingsWithdrawal', 'withdrawal') THEN -t.amount
         ELSE 0 END
  ), 0) INTO v_new_balance
  FROM public.transactions t
  WHERE t.savings_id = v_savings_id;

  v_new_balance := v_opening_balance + v_new_balance;
  IF v_new_balance < 0 THEN v_new_balance := 0; END IF;

  -- 5. Recalculate next_due_date
  SELECT collection_type, start_date INTO v_collection_type, v_start_date
  FROM public.savings_plans WHERE id = v_savings_id;

  SELECT MAX(collection_date) INTO v_max_paid_date
  FROM public.savings_collections
  WHERE savings_plan_id = v_savings_id;

  IF v_max_paid_date IS NULL THEN
    v_new_next_due := v_start_date;
  ELSE
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := v_max_paid_date + 1;
      WHEN 'weekly' THEN
        v_new_next_due := v_max_paid_date + 7;
      ELSE
        v_new_next_due := v_max_paid_date + INTERVAL '1 month';
    END CASE;
  END IF;

  -- 6. Update savings plan with recalculated installments_paid from COUNT of remaining collections
  UPDATE public.savings_plans
  SET
    current_amount = v_new_balance,
    next_due_date = v_new_next_due,
    installments_paid = GREATEST(
      0,
      COALESCE((
        SELECT COUNT(*) FROM public.savings_collections sc
        WHERE sc.savings_plan_id = v_savings_id
      ), 0)
    ),
    updated_at = NOW()
  WHERE id = v_savings_id;

  RETURN jsonb_build_object(
    'success', true,
    'savings_id', v_savings_id,
    'new_balance', v_new_balance,
    'new_next_due_date', v_new_next_due
  );
END;
$$;


ALTER FUNCTION "public"."delete_savings_transaction"("p_transaction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_transaction_with_revert"("p_transaction_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_tx RECORD;
    v_collection RECORD;
BEGIN
    -- 1. Get the transaction
    SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
    
    IF v_tx IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
    END IF;

    -- 2. If it's an EMI payment with a loan_id, revert the EMI and loan
    IF v_tx.loan_id IS NOT NULL AND v_tx.type = 'emiPayment' THEN
        -- Revert the most recently paid EMI for this loan
        UPDATE public.emi_schedule
        SET is_paid = false,
            status = 'pending',
            paid_on = NULL,
            payment_mode = NULL
        WHERE ctid = (
            SELECT ctid FROM public.emi_schedule
            WHERE loan_id = v_tx.loan_id
              AND is_paid = true
              AND paid_on IS NOT NULL
            ORDER BY paid_on DESC
            LIMIT 1
        );

        -- Revert loan outstanding amount
        UPDATE public.loans
        SET outstanding_amount = outstanding_amount + v_tx.amount,
            outstanding_balance = outstanding_balance + v_tx.amount,
            status = CASE WHEN status = 'closed' THEN 'active' ELSE status END
        WHERE id = v_tx.loan_id;

        -- Find and delete the matching collection record
        SELECT id INTO v_collection FROM public.collections
        WHERE loan_id = v_tx.loan_id
          AND ABS(amount_collected - v_tx.amount) < 0.01
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_collection.id IS NOT NULL THEN
            -- Revert staff wallet if applicable
            UPDATE public.staff_wallet
            SET cash_in_hand = cash_in_hand - v_tx.amount,
                total_collected_today = GREATEST(total_collected_today - v_tx.amount, 0),
                last_updated = now()
            WHERE staff_id = (
                SELECT staff_id FROM public.collections WHERE id = v_collection.id
            );

            DELETE FROM public.collections WHERE id = v_collection.id;
        END IF;
    END IF;

    -- 3. Delete the transaction itself
    DELETE FROM public.transactions WHERE id = p_transaction_id;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_id', p_transaction_id,
        'reverted_amount', v_tx.amount
    );
END;
$$;


ALTER FUNCTION "public"."delete_transaction_with_revert"("p_transaction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_members_profile_link"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_resolved_profile_id UUID;
BEGIN
  IF NEW.profile_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF auth.uid() IS NOT NULL THEN
    SELECT id INTO v_resolved_profile_id
    FROM public.profiles
    WHERE user_id = auth.uid()
    LIMIT 1;
    IF v_resolved_profile_id IS NOT NULL THEN
      NEW.profile_id := v_resolved_profile_id;
      RETURN NEW;
    END IF;
  END IF;
  IF NEW.email IS NOT NULL AND NEW.email <> '' THEN
    SELECT p.id INTO v_resolved_profile_id
    FROM public.profiles p
    JOIN auth.users au ON au.id = p.user_id
    WHERE au.email = NEW.email
    LIMIT 1;
    IF v_resolved_profile_id IS NOT NULL THEN
      NEW.profile_id := v_resolved_profile_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."ensure_members_profile_link"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fill_collector_snapshot"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_profile_id uuid;
  v_name text;
  v_role text;
BEGIN
  -- Resolve collector profile id: explicit > auth.uid() lookup
  IF NEW.collected_by_user_id IS NULL THEN
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NOT NULL THEN
      SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = v_auth_uid LIMIT 1;
      NEW.collected_by_user_id := v_profile_id;
    END IF;
  END IF;

  -- Snapshot name/role from profile (don't overwrite if caller supplied)
  IF NEW.collected_by_user_id IS NOT NULL
     AND (NEW.collected_by_name IS NULL OR NEW.collected_by_role IS NULL) THEN
    SELECT full_name, role INTO v_name, v_role
      FROM public.profiles WHERE id = NEW.collected_by_user_id;
    IF NEW.collected_by_name IS NULL THEN NEW.collected_by_name := v_name; END IF;
    IF NEW.collected_by_role IS NULL THEN NEW.collected_by_role := v_role; END IF;
  END IF;

  -- Default entered_by to the same person if not provided
  IF NEW.entered_by_user_id IS NULL THEN
    NEW.entered_by_user_id := NEW.collected_by_user_id;
  END IF;
  IF NEW.entered_by_user_id IS NOT NULL AND NEW.entered_by_name IS NULL THEN
    SELECT full_name INTO NEW.entered_by_name
      FROM public.profiles WHERE id = NEW.entered_by_user_id;
  END IF;

  IF NEW.collected_at IS NULL THEN
    NEW.collected_at := now();
  END IF;

  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fill_collector_snapshot"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fix_upi_collection_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  confirmed_ts TIMESTAMPTZ;
BEGIN
  -- Only act on confirmed UPI rows tied to a loan (customer-side UPI)
  IF NEW.payment_mode = 'upi' AND NEW.loan_id IS NOT NULL THEN
    SELECT upr.confirmed_at INTO confirmed_ts
    FROM public.upi_payment_requests upr
    WHERE upr.loan_id = NEW.loan_id
      AND upr.amount::numeric = NEW.amount_collected::numeric
      AND upr.confirmed_at IS NOT NULL
      AND ABS(EXTRACT(EPOCH FROM (upr.confirmed_at - NEW.created_at))) < 3600
    ORDER BY ABS(EXTRACT(EPOCH FROM (upr.confirmed_at - NEW.created_at)))
    LIMIT 1;

    IF confirmed_ts IS NOT NULL THEN
      NEW.created_at      := confirmed_ts;
      NEW.collected_at    := confirmed_ts;
      NEW.collection_time := to_char(confirmed_ts AT TIME ZONE 'Asia/Kolkata', 'HH24:MI:SS');
      NEW.collection_date := to_char(confirmed_ts AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fix_upi_collection_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fix_upi_transaction_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  confirmed_ts TIMESTAMPTZ;
BEGIN
  -- Only act on UPI emiPayment rows
  IF NEW.payment_mode = 'upi' AND NEW.loan_id IS NOT NULL THEN
    SELECT confirmed_at INTO confirmed_ts
    FROM public.upi_payment_requests
    WHERE transaction_ref = NEW.id::text
       OR id::text = NEW.description
    LIMIT 1;
    -- If we don't find by id, try matching by loan/amount/within 1 hour
    IF confirmed_ts IS NULL THEN
      SELECT upr.confirmed_at INTO confirmed_ts
      FROM public.upi_payment_requests upr
      WHERE upr.loan_id = NEW.loan_id
        AND upr.amount::numeric = NEW.amount::numeric
        AND upr.confirmed_at IS NOT NULL
        AND ABS(EXTRACT(EPOCH FROM (upr.confirmed_at - NEW.created_at))) < 3600
      ORDER BY ABS(EXTRACT(EPOCH FROM (upr.confirmed_at - NEW.created_at)))
      LIMIT 1;
    END IF;
    IF confirmed_ts IS NOT NULL THEN
      NEW.created_at = confirmed_ts;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fix_upi_transaction_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_emi_schedule"("p_loan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_amount NUMERIC;
    v_interest_rate NUMERIC;
    v_tenure_months INTEGER;
    v_interest_type TEXT;
    v_frequency TEXT;
    v_first_installment_date DATE;
    v_emi_amount NUMERIC;
    v_customer_id UUID;
    v_org_id UUID;
    
    v_number_of_installments INTEGER;
    v_annual_rate NUMERIC;
    v_monthly_rate NUMERIC;
    v_rate_per_period NUMERIC;
    v_emi_to_use NUMERIC;
    v_balance NUMERIC;
    v_interest NUMERIC;
    v_principal_paid NUMERIC;
    v_due_date DATE;
    v_start_date DATE;
    v_periods_per_year NUMERIC;
    i INTEGER;
BEGIN
    -- 1. Fetch loan details
    SELECT 
        amount, interest_rate, tenure_months, interest_type, 
        frequency, first_installment_date, emi_amount, customer_id, org_id
    INTO 
        v_amount, v_interest_rate, v_tenure_months, v_interest_type, 
        v_frequency, v_first_installment_date, v_emi_to_use, v_customer_id, v_org_id
    FROM public.loans
    WHERE id = p_loan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan with ID % not found', p_loan_id;
    END IF;

    -- 2. Clear any existing schedule to avoid duplicates
    DELETE FROM public.emi_schedule WHERE loan_id = p_loan_id;

    -- Set default values
    v_balance := v_amount;
    v_annual_rate := v_interest_rate / 100.0;
    v_monthly_rate := v_annual_rate / 12.0;

    -- Determine periods per year & number of installments
    IF v_frequency = 'daily' THEN
        v_periods_per_year := 365.0;
        v_number_of_installments := v_tenure_months * 30;
    ELSIF v_frequency = 'weekly' THEN
        v_periods_per_year := 52.0;
        v_number_of_installments := ROUND(v_tenure_months * 30.0 / 7.0);
    ELSIF v_frequency = 'yearly' THEN
        v_periods_per_year := 1.0;
        v_number_of_installments := GREATEST(1, ROUND(v_tenure_months / 12.0));
    ELSE -- monthly
        v_periods_per_year := 12.0;
        v_number_of_installments := v_tenure_months;
    END IF;

    v_rate_per_period := v_annual_rate / v_periods_per_year;

    -- Calculate EMI if not specified
    IF v_emi_to_use IS NULL OR v_emi_to_use <= 0 THEN
        IF v_interest_type = 'reducing' OR v_interest_type = 'reducingBalance' THEN
            IF v_rate_per_period = 0 THEN
                v_emi_to_use := v_amount / v_number_of_installments;
            ELSE
                v_emi_to_use := (v_amount * v_rate_per_period * POWER(1.0 + v_rate_per_period, v_number_of_installments)) / 
                                (POWER(1.0 + v_rate_per_period, v_number_of_installments) - 1.0);
            END IF;
        ELSE -- Flat
            v_emi_to_use := (v_amount + (v_amount * v_annual_rate * (v_tenure_months / 12.0))) / v_number_of_installments;
        END IF;
    END IF;

    v_start_date := COALESCE(v_first_installment_date, CURRENT_DATE);

    -- 3. Loop and insert schedule
    FOR i IN 1..v_number_of_installments LOOP
        -- Calculate interest and principal paid
        IF v_interest_type = 'reducing' OR v_interest_type = 'reducingBalance' THEN
            v_interest := v_balance * v_rate_per_period;
            v_principal_paid := v_emi_to_use - v_interest;
        ELSE -- Flat
            v_interest := (v_amount * v_annual_rate * (v_tenure_months / 12.0)) / v_number_of_installments;
            v_principal_paid := v_emi_to_use - v_interest;
        END IF;

        IF i = v_number_of_installments THEN
            v_principal_paid := v_balance;
            v_emi_to_use := v_principal_paid + v_interest;
        END IF;

        v_balance := v_balance - v_principal_paid;
        IF v_balance < 0 THEN
            v_balance := 0;
        END IF;

        -- Calculate due date
        IF v_frequency = 'daily' THEN
            v_due_date := v_start_date + (i - 1) * INTERVAL '1 day';
        ELSIF v_frequency = 'weekly' THEN
            v_due_date := v_start_date + (i - 1) * INTERVAL '1 week';
        ELSIF v_frequency = 'yearly' THEN
            v_due_date := v_start_date + (i - 1) * INTERVAL '1 year';
        ELSE -- monthly
            v_due_date := v_start_date + (i - 1) * INTERVAL '1 month';
        END IF;

        INSERT INTO public.emi_schedule (
            id, loan_id, org_id, member_id, emi_number, installment_number, period,
            due_date, emi_amount, emi, principal, interest, balance_after,
            status, is_paid, is_overdue, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), p_loan_id, v_org_id, v_customer_id, i, i, i,
            v_due_date, v_emi_to_use, v_emi_to_use, v_principal_paid, v_interest, v_balance,
            'pending', false, false, NOW(), NOW()
        );
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."generate_emi_schedule"("p_loan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_verification_token"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$;


ALTER FUNCTION "public"."generate_verification_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_daily_summary"("p_branch_id" "uuid", "p_date" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_collections', COALESCE(SUM(c.amount_collected), 0),
        'total_visits', COUNT(c.id),
        'completed_tasks', 0
    ) INTO result
    FROM collections c
    JOIN staff_profiles sp ON c.staff_id = sp.id
    WHERE sp.branch_id = p_branch_id
      AND c.collection_date = p_date;

    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_branch_daily_summary"("p_branch_id" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_staff_performance"("p_branch_id" "uuid", "p_start_date" "date" DEFAULT (CURRENT_DATE - '30 days'::interval), "p_end_date" "date" DEFAULT CURRENT_DATE) RETURNS TABLE("name" "text", "collected" numeric, "efficiency" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sp.full_name AS name,
        COALESCE(SUM(c.amount_collected), 0) AS collected,
        CASE 
            WHEN COUNT(c.id) = 0 THEN 0
            ELSE LEAST(100, (SUM(c.amount_collected) / (sp.daily_collection_target * (p_end_date - p_start_date + 1))::DECIMAL * 100)::INTEGER)
        END AS efficiency
    FROM staff_profiles sp
    LEFT JOIN collections c ON c.staff_id = sp.id 
        AND c.collection_date BETWEEN p_start_date AND p_end_date
    WHERE sp.branch_id = p_branch_id
    GROUP BY sp.id, sp.full_name, sp.daily_collection_target
    ORDER BY collected DESC;
END;
$$;


ALTER FUNCTION "public"."get_branch_staff_performance"("p_branch_id" "uuid", "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_stats"("p_branch_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    branch_record RECORD;
    result JSONB;
BEGIN
    SELECT id, name, address, status INTO branch_record
    FROM branches WHERE id = p_branch_id;

    IF branch_record IS NULL THEN
        RETURN jsonb_build_object(
            'branch_id', p_branch_id,
            'branch_name', 'Unknown',
            'branch_address', '',
            'is_active', false,
            'total_staff', 0,
            'total_members', 0,
            'total_loans', 0,
            'total_savings', 0,
            'active_loans', 0,
            'overdue_loans', 0,
            'total_collections', 0,
            'total_disbursements', 0,
            'outstanding_amount', 0
        );
    END IF;

    result := jsonb_build_object(
        'branch_id', branch_record.id,
        'branch_name', branch_record.name,
        'branch_address', branch_record.address,
        'is_active', (branch_record.status = 'active'),
        'total_staff', (SELECT COUNT(*) FROM profiles WHERE branch_id = p_branch_id),
        'total_members', (SELECT COUNT(*) FROM members WHERE branch_id = p_branch_id),
        'total_loans', (SELECT COUNT(*) FROM loans l JOIN members m ON l.member_id = m.id WHERE m.branch_id = p_branch_id),
        'total_savings', COALESCE((SELECT SUM(balance) FROM savings s JOIN members m ON s.member_id = m.id WHERE m.branch_id = p_branch_id), 0),
        'active_loans', (SELECT COUNT(*) FROM loans l JOIN members m ON l.member_id = m.id WHERE m.branch_id = p_branch_id AND l.status = 'active'),
        'overdue_loans', 0,
        'total_collections', COALESCE((SELECT SUM(amount_collected) FROM collections c JOIN staff_profiles sp ON c.staff_id = sp.id WHERE sp.branch_id = p_branch_id), 0),
        'total_disbursements', 0,
        'outstanding_amount', COALESCE((SELECT SUM(outstanding_balance) FROM loans l JOIN members m ON l.member_id = m.id WHERE m.branch_id = p_branch_id AND l.status = 'active'), 0)
    );

    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_branch_stats"("p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_frequent_customers"("p_staff_id" "uuid", "p_limit" integer DEFAULT 10) RETURNS SETOF "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT jsonb_build_object(
    'member_id', c.member_id,
    'member_name', c.member_name,
    'member_phone', c.member_phone,
    'collection_count', COUNT(*),
    'total_amount', SUM(c.amount_collected),
    'last_collection', MAX(c.collection_date)
  )
  FROM public.collections c
  WHERE c.staff_id = p_staff_id
  GROUP BY c.member_id, c.member_name, c.member_phone
  ORDER BY COUNT(*) DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_frequent_customers"("p_staff_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_latest_staff_locations"("p_org_id" "uuid") RETURNS TABLE("staff_id" "uuid", "full_name" "text", "staff_code" "text", "branch_name" "text", "latitude" numeric, "longitude" numeric, "accuracy" numeric, "speed" numeric, "heading" numeric, "activity_type" "text", "battery_level" numeric, "is_charging" boolean, "is_active" boolean, "recorded_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT DISTINCT ON (sl.staff_id)
      sl.staff_id,
      COALESCE(sp.full_name, p.full_name) AS full_name,
      COALESCE(sp.staff_code, p.staff_code, '') AS staff_code,
      b.name AS branch_name,
      sl.latitude,
      sl.longitude,
      sl.accuracy,
      sl.speed,
      sl.heading,
      sl.activity_type,
      sl.battery_level,
      sl.is_charging,
      sl.is_active,
      sl.recorded_at
  FROM public.staff_locations sl
  LEFT JOIN public.staff_profiles sp ON sp.id = sl.staff_id
  LEFT JOIN public.profiles p ON p.id = sl.staff_id
  LEFT JOIN public.branches b ON b.id = COALESCE(sp.branch_id, p.branch_id)
  WHERE sl.org_id = p_org_id
    AND sl.recorded_at >= (CURRENT_DATE AT TIME ZONE 'utc')
  ORDER BY sl.staff_id, sl.recorded_at DESC;
$$;


ALTER FUNCTION "public"."get_latest_staff_locations"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_member_id_for_auth"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT m.id FROM public.members m
  JOIN public.profiles p ON p.id = m.profile_id
  WHERE p.user_id = auth.uid()
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_member_id_for_auth"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_platform_metrics"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_organizations', (SELECT COUNT(*) FROM organizations),
    'active_organizations', (SELECT COUNT(*) FROM organizations WHERE status = 'active'),
    'total_users', (SELECT COUNT(*) FROM profiles),
    'active_users', (SELECT COUNT(*) FROM profiles WHERE is_active = true OR is_active IS NULL),
    'total_branches', (SELECT COUNT(*) FROM branches),
    'total_members', (SELECT COUNT(*) FROM members),
    'total_loans', (SELECT COUNT(*) FROM loans),
    'total_loan_amount', COALESCE((SELECT SUM(amount) FROM loans), 0),
    'total_collections', COALESCE((SELECT SUM(amount_collected) FROM collections), 0),
    'total_savings', COALESCE((SELECT SUM(balance) FROM savings), 0),
    'mrr', 0,
    'last_updated', now()
  ) INTO result;
  
  RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_platform_metrics"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_staff_rank"("p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_rank integer;
BEGIN
  SELECT rank INTO v_rank
  FROM (
    SELECT staff_id, RANK() OVER (ORDER BY total_points DESC) as rank
    FROM public.staff_points
  ) ranked
  WHERE ranked.staff_id = p_staff_id;

  RETURN jsonb_build_object('rank', v_rank);
END;
$$;


ALTER FUNCTION "public"."get_staff_rank"("p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subscription_status"("p_org_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'org_id', o.id,
    'status', COALESCE(o.status, 'active'),
    'plan_name', 'standard',
    'trial_ends_at', o.trial_ends_at,
    'created_at', o.created_at,
    'member_count', (SELECT COUNT(*) FROM public.members WHERE org_id = p_org_id),
    'loan_count', (SELECT COUNT(*) FROM public.loans WHERE org_id = p_org_id),
    'branch_count', (SELECT COUNT(*) FROM public.branches WHERE org_id = p_org_id)
  ) INTO v_result
  FROM public.organizations o
  WHERE o.id = p_org_id;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_subscription_status"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_org_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT COALESCE(
    (SELECT org_id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1),
    '00000000-0000-0000-0000-000000000001'::uuid
  );
$$;


ALTER FUNCTION "public"."get_user_org_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT COALESCE(
    (SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1),
    'customer'
  );
$$;


ALTER FUNCTION "public"."get_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_collector_snapshot_immutable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.collected_by_user_id IS DISTINCT FROM OLD.collected_by_user_id
     OR NEW.collected_by_name  IS DISTINCT FROM OLD.collected_by_name
     OR NEW.collected_by_role  IS DISTINCT FROM OLD.collected_by_role
     OR NEW.collected_at       IS DISTINCT FROM OLD.collected_at THEN
    RAISE EXCEPTION 'Collector snapshot fields are immutable on % (id=%). Post a reversing entry instead.',
      TG_TABLE_NAME, OLD.id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."guard_collector_snapshot_immutable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user_creates_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_existing_profile_id UUID;
  v_metadata_org_id UUID;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', NEW.raw_app_meta_data->>'role', 'customer');
  SELECT id INTO v_existing_profile_id
  FROM public.profiles
  WHERE user_id = NEW.id
  LIMIT 1;
  IF v_existing_profile_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  BEGIN
    v_metadata_org_id := (NEW.raw_user_meta_data->>'org_id')::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_metadata_org_id := NULL;
  END;
  INSERT INTO public.profiles (
    user_id, full_name, email, role, org_id, status, is_active
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    v_role,
    v_metadata_org_id,
    'active',
    true
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user_creates_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (
    user_id, email, full_name, phone, role, org_id, branch_id, status, created_at, updated_at
  )
  VALUES (
    NEW.id::text,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
    NEW.raw_app_meta_data->>'org_id',
    (NEW.raw_user_meta_data->>'branch_id')::uuid,
    'active',
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_invitation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE public.org_invitations SET status = 'revoked'
    WHERE org_id = NEW.org_id AND email = NEW.email AND status = 'pending' AND id != NEW.id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_invitation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user_welcome"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_email TEXT;
BEGIN
    v_user_email := NEW.email;
    INSERT INTO public.staff_notifications (staff_id, title, message, type, priority)
    SELECT 
        sp.id,
        'Welcome to MicroFlow Pro',
        'Welcome, ' || COALESCE(NEW.raw_user_meta_data->>'full_name', v_user_email) || '!',
        'system',
        'normal'
    FROM public.staff_profiles sp
    WHERE sp.user_id = NEW.id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user_welcome"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'superAdmin');
$$;


ALTER FUNCTION "public"."is_super_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."link_member_to_profile_on_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  resolved_id uuid;
BEGIN
  IF NEW.profile_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.email IS NULL OR LENGTH(TRIM(NEW.email)) = 0 THEN
    RETURN NEW;
  END IF;

  IF OLD.email IS NOT NULL AND
     LOWER(TRIM(OLD.email)) = LOWER(TRIM(NEW.email)) THEN
    RETURN NEW;
  END IF;

  SELECT p.id INTO resolved_id
  FROM public.profiles p
  JOIN auth.users au ON au.id::text = p.user_id::text
  WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(NEW.email))
  LIMIT 1;

  IF resolved_id IS NOT NULL THEN
    NEW.profile_id := resolved_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."link_member_to_profile_on_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_audit_event"("p_org_id" "uuid", "p_user_id" "uuid" DEFAULT NULL::"uuid", "p_action" "text" DEFAULT NULL::"text", "p_entity_type" "text" DEFAULT NULL::"text", "p_entity_id" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_old_values" "jsonb" DEFAULT NULL::"jsonb", "p_new_values" "jsonb" DEFAULT NULL::"jsonb", "p_severity" "text" DEFAULT 'info'::"text", "p_category" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_email text;
  v_user_name text;
BEGIN
  -- Look up user details if user_id provided
  IF p_user_id IS NOT NULL THEN
    SELECT email, full_name INTO v_user_email, v_user_name
    FROM public.profiles WHERE id = p_user_id;
  END IF;

  INSERT INTO public.audit_logs (
    org_id, user_id, user_email, user_name,
    action, entity_type, entity_id, description,
    old_values, new_values, severity, category, created_at
  ) VALUES (
    p_org_id, p_user_id, v_user_email, v_user_name,
    p_action, p_entity_type, p_entity_id, p_description,
    p_old_values, p_new_values, p_severity, p_category, now()
  );
END;
$$;


ALTER FUNCTION "public"."log_audit_event"("p_org_id" "uuid", "p_user_id" "uuid", "p_action" "text", "p_entity_type" "text", "p_entity_id" "text", "p_description" "text", "p_old_values" "jsonb", "p_new_values" "jsonb", "p_severity" "text", "p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_member_profile_link_fix"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF OLD.profile_id IS NULL AND NEW.profile_id IS NOT NULL THEN
    INSERT INTO public.audit_logs (
      org_id, actor_id, action, entity_type, entity_id, metadata
    ) VALUES (
      NEW.org_id,
      auth.uid(),
      'members.profile_id_backfilled',
      'member',
      NEW.id::text,
      jsonb_build_object(
        'member_email', NEW.email,
        'profile_id', NEW.profile_id,
        'source', 'trg_log_member_profile_link_fix'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_member_profile_link_fix"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_super_admin_auth_deletion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = OLD.id AND role = 'superAdmin'
    ) THEN
        RAISE EXCEPTION 'Cannot delete super admin auth account - protected account';
    END IF;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."prevent_super_admin_auth_deletion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_super_admin_deletion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF OLD.role = 'superAdmin' THEN
        RAISE EXCEPTION 'Cannot delete super admin profile - protected account';
    END IF;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."prevent_super_admin_deletion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_super_admin_role_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF OLD.role = 'superAdmin' AND NEW.role != 'superAdmin' THEN
        RAISE EXCEPTION 'Cannot change super admin role - protected account';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_super_admin_role_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rebuild_emi_schedule_from_collections"("p_loan_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_collected DECIMAL(12,2) := 0;
  v_emi RECORD;
  v_remaining DECIMAL(12,2);
  v_emis_marked INTEGER := 0;
  v_rec_result JSONB;
  v_first_collection_date DATE;
BEGIN
  -- 1. Sum all collections for this loan
  SELECT COALESCE(SUM(amount_collected), 0),
         MIN(collection_date)
  INTO v_total_collected, v_first_collection_date
  FROM public.collections
  WHERE loan_id = p_loan_id;

  IF v_total_collected <= 0 THEN
    RETURN jsonb_build_object('success', true, 'note', 'no collections', 'collected', 0);
  END IF;

  -- 2. Walk EMIs from oldest to newest, marking as paid
  --    until we've accounted for total collected amount
  v_remaining := v_total_collected;

  FOR v_emi IN
    SELECT id, emi_amount, is_paid, emi_number
    FROM public.emi_schedule
    WHERE loan_id = p_loan_id
    ORDER BY emi_number ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    IF v_emi.is_paid = false THEN
      UPDATE public.emi_schedule
      SET
        is_paid = true,
        status = 'paid',
        amount_paid = v_emi.emi_amount,
        paid_on = COALESCE(v_first_collection_date, CURRENT_DATE)::text || 'T00:00:00Z',
        payment_mode = 'migrated'
      WHERE id = v_emi.id;

      v_emis_marked := v_emis_marked + 1;
    END IF;

    v_remaining := v_remaining - v_emi.emi_amount;
  END LOOP;

  -- 3. Recalculate outstanding from corrected emi_schedule
  SELECT public.recalculate_loan_outstanding(p_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', p_loan_id,
    'total_collected', v_total_collected,
    'emis_marked', v_emis_marked,
    'recalc', v_rec_result
  );
END;
$$;


ALTER FUNCTION "public"."rebuild_emi_schedule_from_collections"("p_loan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_loan_outstanding"("p_loan_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_repaid DECIMAL(12,2) := 0;
  v_paid_count INTEGER := 0;
  v_total_emi DECIMAL(12,2) := 0;
  v_loan_amount DECIMAL(12,2) := 0;
  v_new_outstanding DECIMAL(12,2) := 0;
  v_total_repayable DECIMAL(12,2) := 0;
BEGIN
  -- Sum up what's actually been paid according to EMI schedule
  SELECT
    COALESCE(SUM(CASE WHEN is_paid THEN emi_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN is_paid THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(emi_amount), 0)
  INTO v_total_repaid, v_paid_count, v_total_emi
  FROM public.emi_schedule
  WHERE loan_id = p_loan_id;

  -- Get loan's principal amount
  SELECT COALESCE(amount, 0) INTO v_loan_amount
  FROM public.loans WHERE id = p_loan_id;

  -- outstanding = total repayable - what's been paid
  v_new_outstanding := v_total_emi - v_total_repaid;
  IF v_new_outstanding < 0 THEN v_new_outstanding := 0; END IF;

  -- Update the loan
  UPDATE public.loans
  SET
    outstanding_amount = v_new_outstanding,
    outstanding_balance = v_new_outstanding,
    paid_emis = v_paid_count,
    status = CASE
      WHEN v_new_outstanding <= 0 AND status != 'closed' THEN 'closed'
      WHEN v_new_outstanding > 0 AND status = 'closed' THEN 'active'
      ELSE status
    END
  WHERE id = p_loan_id;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', p_loan_id,
    'total_repaid', v_total_repaid,
    'paid_emis', v_paid_count,
    'total_emi', v_total_emi,
    'new_outstanding', v_new_outstanding
  );
END;
$$;


ALTER FUNCTION "public"."recalculate_loan_outstanding"("p_loan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_savings_balance"("p_savings_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_opening DECIMAL(12,2) := 0;
  v_new_balance DECIMAL(12,2) := 0;
  v_collection_type TEXT;
  v_start_date DATE;
  v_max_paid_date DATE;
  v_new_next_due DATE;
BEGIN
  -- 1. Pull plan metadata
  SELECT
    COALESCE(opening_balance, 0),
    COALESCE(collection_type, 'monthly'),
    start_date
  INTO v_opening, v_collection_type, v_start_date
  FROM public.savings_plans
  WHERE id = p_savings_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'savings plan not found');
  END IF;

  -- 2. Recompute balance from remaining transactions
  SELECT COALESCE(SUM(
    CASE
      WHEN t.type IN ('savingsWithdrawal', 'withdrawal') THEN -t.amount
      ELSE t.amount
    END
  ), 0) INTO v_new_balance
  FROM public.transactions t
  WHERE t.savings_id = p_savings_id;

  v_new_balance := v_opening + v_new_balance;
  IF v_new_balance < 0 THEN v_new_balance := 0; END IF;

  -- 3. Recompute next_due_date from the latest remaining collection
  SELECT MAX(collection_date) INTO v_max_paid_date
  FROM public.savings_collections
  WHERE savings_plan_id = p_savings_id;

  IF v_max_paid_date IS NOT NULL THEN
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := v_max_paid_date + 1;
      WHEN 'weekly' THEN
        v_new_next_due := v_max_paid_date + 7;
      ELSE
        v_new_next_due := (v_max_paid_date + INTERVAL '1 month')::date;
    END CASE;
  ELSE
    v_new_next_due := v_start_date;
  END IF;

  -- ALWAYS advance if the calculated date is in the past
  IF v_new_next_due < CURRENT_DATE THEN
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := CURRENT_DATE;
      WHEN 'weekly' THEN
        v_new_next_due := CURRENT_DATE + (7 - EXTRACT(DOW FROM CURRENT_DATE)::int + EXTRACT(DOW FROM v_start_date)::int)::int % 7;
        IF v_new_next_due <= CURRENT_DATE THEN
          v_new_next_due := CURRENT_DATE + 1;
        END IF;
      ELSE
        v_new_next_due := CURRENT_DATE;
    END CASE;
  END IF;

  -- 4. Persist with installments_paid recalculated from live savings_collections
  UPDATE public.savings_plans
  SET current_amount = v_new_balance,
      next_due_date = v_new_next_due,
      installments_paid = GREATEST(
        0,
        COALESCE((
          SELECT COUNT(*) FROM public.savings_collections sc
          WHERE sc.savings_plan_id = p_savings_id
        ), 0)
      ),
      updated_at = NOW()
  WHERE id = p_savings_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'next_due_date', v_new_next_due
  );
END;
$$;


ALTER FUNCTION "public"."recalculate_savings_balance"("p_savings_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."require_member_profile_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  resolved_id uuid;
  has_email   boolean;
BEGIN
  -- If profile_id is provided, validate it exists.
  IF NEW.profile_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.profile_id) THEN
      RAISE EXCEPTION
        'members.profile_id=% does not reference a real profiles row', NEW.profile_id;
    END IF;
    RETURN NEW;
  END IF;

  -- profile_id is NULL â€” try to resolve via auth.uid() -> profiles.user_id
  -- (works when the caller is the auth user, e.g. self-signup).
  IF auth.uid() IS NOT NULL THEN
    SELECT id INTO resolved_id
    FROM public.profiles
    WHERE user_id::text = auth.uid()::text
    LIMIT 1;

    IF resolved_id IS NOT NULL THEN
      NEW.profile_id := resolved_id;
      RETURN NEW;
    END IF;
  END IF;

  -- profile_id is still NULL. Decide based on whether email is set.
  has_email := (NEW.email IS NOT NULL AND LENGTH(TRIM(NEW.email)) > 0);

  IF has_email THEN
    RAISE EXCEPTION
      'Cannot insert members row with email=%, NULL profile_id and no resolvable profile. '
      'Either provide profile_id, or ensure a profiles row exists for the matching auth user. '
      'See migration 20260602_add_profile_link_safety_triggers for context.',
      NEW.email;
  END IF;

  -- Email-less / staff-collected record. Allow with NULL profile_id.
  -- Customer portal will not be accessible for this member until a
  -- profile is later linked (Part F handles that).
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."require_member_profile_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resend_invitation"("p_invitation_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE public.org_invitations SET token = encode(gen_random_bytes(32), 'hex'), expires_at = now() + interval '7 days', status = 'pending'
    WHERE id = p_invitation_id AND org_id = public.get_user_org_id() AND status IN ('pending', 'expired');
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."resend_invitation"("p_invitation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revoke_invitation"("p_invitation_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE public.org_invitations SET status = 'revoked' WHERE id = p_invitation_id AND org_id = public.get_user_org_id();
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."revoke_invitation"("p_invitation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_collection_is_backdated"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE public.collections
    SET is_backdated = TRUE
    WHERE id = NEW.collection_id
      AND is_backdated = FALSE;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_collection_is_backdated"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_member_branch_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.branch_id IS DISTINCT FROM OLD.branch_id THEN
    UPDATE public.members
    SET branch_id = NEW.branch_id
    WHERE profile_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_member_branch_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_member_name_to_profiles"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.full_name IS DISTINCT FROM OLD.full_name AND NEW.profile_id IS NOT NULL THEN
    UPDATE profiles SET full_name = NEW.full_name WHERE id = NEW.profile_id;
  END IF;
  IF NEW.phone IS DISTINCT FROM OLD.phone AND NEW.profile_id IS NOT NULL THEN
    UPDATE profiles SET phone = NEW.phone WHERE id = NEW.profile_id;
  END IF;
  IF NEW.email IS DISTINCT FROM OLD.email AND NEW.profile_id IS NOT NULL THEN
    UPDATE profiles SET email = NEW.email WHERE id = NEW.profile_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_member_name_to_profiles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_profile_name_to_members"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.full_name IS DISTINCT FROM OLD.full_name THEN
    UPDATE members SET full_name = NEW.full_name WHERE profile_id = NEW.id;
  END IF;
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    UPDATE members SET phone = NEW.phone WHERE profile_id = NEW.id;
  END IF;
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE members SET email = NEW.email WHERE profile_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_profile_name_to_members"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_func_simple"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."test_func_simple"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_admin_notes_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."touch_admin_notes_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_data_exports_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_data_exports_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_schedule_on_collection"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_remaining_amount DECIMAL(12, 2);
    v_emi_record RECORD;
    v_current_outstanding DECIMAL(12, 2);
    v_total_repayable DECIMAL(12, 2);
    v_emi_cursor CURSOR FOR 
        SELECT id, emi_amount 
        FROM public.emi_schedule 
        WHERE loan_id = NEW.loan_id 
          AND is_paid = false 
          AND paid_on IS NULL
        ORDER BY emi_number ASC;
BEGIN
    -- Only proceed for loan collections
    IF NEW.loan_id IS NOT NULL THEN
        v_remaining_amount := NEW.amount_collected;
        
        -- Iterate through unpaid EMIs oldest first, marking as many as the amount covers
        FOR v_emi_record IN v_emi_cursor LOOP
            EXIT WHEN v_remaining_amount <= 0;
            
            IF v_remaining_amount >= v_emi_record.emi_amount THEN
                -- Full payment of this EMI
                UPDATE public.emi_schedule
                SET 
                    is_paid = true,
                    status = 'paid',
                    paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                    payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                WHERE id = v_emi_record.id;
                
                v_remaining_amount := v_remaining_amount - v_emi_record.emi_amount;
            ELSE
                -- Partial payment - don't mark as paid
                v_remaining_amount := 0;
            END IF;
        END LOOP;
    END IF;
    
    -- Update loan outstanding amount and outstanding balance
    IF NEW.loan_id IS NOT NULL THEN
        SELECT 
            COALESCE(outstanding_balance, outstanding_amount, total_repayable, amount, 0),
            COALESCE(total_repayable, amount, 0)
        INTO v_current_outstanding, v_total_repayable
        FROM public.loans
        WHERE id = NEW.loan_id;
        
        IF v_current_outstanding <= 0 THEN
            v_current_outstanding := v_total_repayable;
        END IF;

        UPDATE public.loans
        SET 
            outstanding_amount = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            outstanding_balance = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            status = CASE 
                WHEN v_current_outstanding - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_schedule_on_collection"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_schedule_on_collection_v2"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_remaining_amount  DECIMAL(12, 2);
    v_emi_record        RECORD;
    v_current_outstanding DECIMAL(12, 2);
    v_total_repayable     DECIMAL(12, 2);
    v_selected_emi        RECORD;
    v_emis_marked   INT := 0;
    v_emi_cursor CURSOR FOR
        SELECT id, emi_amount
        FROM public.emi_schedule
        WHERE loan_id = NEW.loan_id
          AND is_paid = false
          AND paid_on IS NULL
        ORDER BY emi_number ASC;
BEGIN
    -- Only proceed for loan collections
    IF NEW.loan_id IS NOT NULL THEN
        v_remaining_amount := NEW.amount_collected;

        IF NEW.selected_schedule_id IS NOT NULL THEN
            SELECT id, emi_amount, is_paid
            INTO v_selected_emi
            FROM public.emi_schedule
            WHERE id = NEW.selected_schedule_id
              AND loan_id = NEW.loan_id;

            IF FOUND THEN
                IF v_selected_emi.is_paid IS DISTINCT FROM true THEN
                    IF v_remaining_amount >= v_selected_emi.emi_amount THEN
                        UPDATE public.emi_schedule
                        SET
                            is_paid = true,
                            status = 'paid',
                            paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                            payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                        WHERE id = v_selected_emi.id;
                        v_emis_marked := 1;
                        v_remaining_amount := v_remaining_amount - v_selected_emi.emi_amount;
                    ELSE
                        v_remaining_amount := 0;
                    END IF;
                ELSE
                    RETURN NEW;
                END IF;
            END IF;
        ELSE
            FOR v_emi_record IN v_emi_cursor LOOP
                EXIT WHEN v_remaining_amount <= 0;
                IF v_remaining_amount >= v_emi_record.emi_amount THEN
                    UPDATE public.emi_schedule
                    SET
                        is_paid = true,
                        status = 'paid',
                        paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                        payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                    WHERE id = v_emi_record.id;
                    v_emis_marked := v_emis_marked + 1;
                    v_remaining_amount := v_remaining_amount - v_emi_record.emi_amount;
                ELSE
                    v_remaining_amount := 0;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Update loan outstanding amount and paid_emis
    IF NEW.loan_id IS NOT NULL THEN
        SELECT COALESCE(outstanding_amount, outstanding_balance, total_repayable, amount, 0)
        INTO v_current_outstanding
        FROM public.loans WHERE id = NEW.loan_id;

        UPDATE public.loans
        SET
            outstanding_amount = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            outstanding_balance = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            paid_emis = COALESCE(paid_emis, 0) + v_emis_marked,
            status = CASE
                WHEN v_current_outstanding - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_schedule_on_collection_v2"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_staff_points"("p_staff_id" "uuid", "p_points" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.staff_points (staff_id, total_points, level, updated_at)
  VALUES (p_staff_id, p_points, 1, now())
  ON CONFLICT (staff_id) DO UPDATE
  SET total_points = staff_points.total_points + p_points,
      level = GREATEST(1, (staff_points.total_points + p_points) / 100 + 1),
      updated_at = now();
END;
$$;


ALTER FUNCTION "public"."update_staff_points"("p_staff_id" "uuid", "p_points" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ BEGIN NEW.updated_at = timezone('utc'::text, now()); RETURN NEW; END; $$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_wallet_on_collection"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ BEGIN UPDATE public.staff_wallet SET cash_in_hand = cash_in_hand + NEW.amount_collected, total_collected_today = total_collected_today + NEW.amount_collected, last_updated = timezone('utc'::text, now()) WHERE staff_id = NEW.staff_id; INSERT INTO public.wallet_transactions (staff_id, org_id, type, amount, direction, payment_mode, balance_before, balance_after, collection_id) SELECT w.staff_id, w.org_id, 'collection', NEW.amount_collected, 'in', NEW.payment_mode, w.cash_in_hand - NEW.amount_collected, w.cash_in_hand, NEW.id FROM public.staff_wallet w WHERE w.staff_id = NEW.staff_id; RETURN NEW; END; $$;


ALTER FUNCTION "public"."update_wallet_on_collection"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "code" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "icon" "text" DEFAULT 'trophy'::"text",
    "points" integer DEFAULT 0,
    "category" "text" DEFAULT 'general'::"text",
    "target_value" integer DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "details" "text",
    "type" "text",
    "ip_address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "staff_id" "uuid",
    "entity_type" "text",
    "entity_id" "uuid",
    "metadata" "jsonb",
    "gps_lat" numeric,
    "gps_lng" numeric,
    "gps_address" "text",
    "device_id" "text",
    "app_version" "text",
    "platform" "text",
    "sync_status" "text" DEFAULT 'synced'::"text",
    "user_name" "text",
    CONSTRAINT "activity_logs_type_check" CHECK (("type" = ANY (ARRAY['user'::"text", 'loan'::"text", 'savings'::"text", 'transaction'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "user_profile_id" "uuid" NOT NULL,
    "author_profile_id" "uuid",
    "body" "text" NOT NULL,
    "pinned" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."admin_notes" OWNER TO "postgres";


COMMENT ON TABLE "public"."admin_notes" IS 'Internal admin-only notes attached to a user profile. Visible only to admins of the same organization.';



CREATE TABLE IF NOT EXISTS "public"."agent_areas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "agent_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "area_name" "text",
    "area_polygon" "jsonb",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."agent_areas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."api_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "key_hash" "text" NOT NULL,
    "key_prefix" "text" NOT NULL,
    "permissions" "jsonb" DEFAULT '[]'::"jsonb",
    "is_active" boolean DEFAULT true,
    "expires_at" timestamp with time zone,
    "last_used_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."api_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."api_usage_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "endpoint" "text",
    "method" "text",
    "status_code" integer,
    "response_time_ms" integer,
    "user_id" "uuid",
    "org_id" "uuid",
    "ip_address" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."api_usage_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_updates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "version" "text" NOT NULL,
    "platform" "text" DEFAULT 'all'::"text",
    "release_notes" "text",
    "is_critical" boolean DEFAULT false,
    "min_supported_version" "text",
    "published_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."app_updates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "user_email" "text",
    "user_name" "text",
    "action" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "text",
    "description" "text",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "old_values" "jsonb",
    "new_values" "jsonb",
    "ip_address" "text",
    "user_agent" "text",
    "device_type" "text",
    "severity" "text" DEFAULT 'info'::"text",
    "category" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "audit_logs_severity_check" CHECK (("severity" = ANY (ARRAY['info'::"text", 'warning'::"text", 'error'::"text", 'critical'::"text"])))
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branch_targets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "month" integer NOT NULL,
    "year" integer NOT NULL,
    "collection_target" numeric(12,2) DEFAULT 0.00,
    "new_members_target" integer DEFAULT 0,
    "loans_disbursed_target" integer DEFAULT 0,
    "savings_target" numeric(12,2) DEFAULT 0.00,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "branch_targets_month_check" CHECK ((("month" >= 1) AND ("month" <= 12)))
);


ALTER TABLE "public"."branch_targets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "zone" "text",
    "district" "text",
    "state" "text" DEFAULT 'Tamil Nadu'::"text",
    "manager_id" "uuid",
    "address" "text",
    "phone" "text",
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "city" "text",
    "pincode" "text",
    "email" "text",
    "location_lat" numeric,
    "location_lng" numeric,
    "operating_hours" "jsonb",
    CONSTRAINT "branches_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_deposits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid",
    "org_id" "uuid" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "deposit_date" "date" DEFAULT CURRENT_DATE,
    "deposit_time" time without time zone DEFAULT CURRENT_TIME,
    "bank_name" "text",
    "reference_number" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."cash_deposits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collection_backdate_audit" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "collection_id" "uuid" NOT NULL,
    "original_created_at" timestamp with time zone NOT NULL,
    "entry_collection_date" "date",
    "entry_collection_time" time without time zone,
    "new_collection_date" "date" NOT NULL,
    "new_collection_time" time without time zone NOT NULL,
    "days_back" integer NOT NULL,
    "performed_by" "uuid" NOT NULL,
    "performed_by_role" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "ip_address" "inet",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "collection_backdate_audit_days_back_check" CHECK (("days_back" >= 0)),
    CONSTRAINT "collection_backdate_audit_performed_by_role_check" CHECK (("performed_by_role" = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text"]))),
    CONSTRAINT "collection_backdate_audit_reason_check" CHECK (("length"(TRIM(BOTH FROM "reason")) > 0))
);


ALTER TABLE "public"."collection_backdate_audit" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collection_targets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "period_type" "text" NOT NULL,
    "target_date" "date" NOT NULL,
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "target_amount" numeric(12,2) DEFAULT 0,
    "target_count" integer DEFAULT 0,
    "achieved_amount" numeric(12,2) DEFAULT 0,
    "achieved_count" integer DEFAULT 0,
    "overdue_target_amount" numeric(12,2) DEFAULT 0,
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "collection_targets_period_type_check" CHECK (("period_type" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text"]))),
    CONSTRAINT "collection_targets_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'achieved'::"text", 'partial'::"text", 'missed'::"text"])))
);


ALTER TABLE "public"."collection_targets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."collections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "loan_id" "uuid",
    "loan_schedule_id" "uuid",
    "member_id" "uuid",
    "staff_id" "uuid",
    "member_name" "text",
    "member_phone" "text",
    "loan_number" "text",
    "amount_expected" numeric(12,2) NOT NULL,
    "amount_collected" numeric(12,2) NOT NULL,
    "variance" numeric(12,2) GENERATED ALWAYS AS (("amount_collected" - "amount_expected")) STORED,
    "is_partial" boolean DEFAULT false,
    "is_advance" boolean DEFAULT false,
    "payment_mode" "text" DEFAULT 'cash'::"text",
    "reference_number" "text",
    "gps_lat" numeric(10,8),
    "gps_lng" numeric(11,8),
    "gps_accuracy" numeric(10,2),
    "gps_address" "text",
    "collection_date" "date" DEFAULT CURRENT_DATE,
    "collection_time" time without time zone DEFAULT CURRENT_TIME,
    "receipt_generated" boolean DEFAULT false,
    "sync_status" "text" DEFAULT 'synced'::"text",
    "local_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "receipt_number" "text",
    "type" "text" DEFAULT 'emi'::"text",
    "is_offline" boolean DEFAULT false,
    "collection_type" "text" DEFAULT 'emi'::"text",
    "remarks" "text",
    "branch_id" "uuid",
    "collected_by_user_id" "uuid",
    "collected_by_name" "text",
    "collected_by_role" "text",
    "collected_at" timestamp with time zone,
    "entered_by_user_id" "uuid",
    "entered_by_name" "text",
    "collection_method" "text",
    "sync_attempts" integer DEFAULT 0,
    "last_sync_at" timestamp with time zone,
    "selected_schedule_id" "uuid",
    "is_backdated" boolean DEFAULT false NOT NULL,
    "transaction_id" "uuid",
    CONSTRAINT "collections_collected_by_role_check" CHECK ((("collected_by_role" IS NULL) OR ("collected_by_role" = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text", 'fieldStaff'::"text", 'customer'::"text", 'retailMember'::"text"])))),
    CONSTRAINT "collections_collection_method_check" CHECK ((("collection_method" IS NULL) OR ("collection_method" = ANY (ARRAY['agent_field'::"text", 'branch_counter'::"text", 'online'::"text", 'auto_debit'::"text", 'other'::"text"])))),
    CONSTRAINT "collections_collection_type_check" CHECK (("collection_type" = ANY (ARRAY['emi'::"text", 'overdue'::"text", 'advance'::"text", 'partial'::"text", 'savings'::"text", 'loan'::"text", 'penalty'::"text", 'other'::"text"]))),
    CONSTRAINT "collections_payment_mode_check" CHECK (("payment_mode" = ANY (ARRAY['cash'::"text", 'upi'::"text", 'bankTransfer'::"text", 'bank'::"text", 'cheque'::"text", 'card'::"text", 'adjustment'::"text", 'other'::"text"]))),
    CONSTRAINT "collections_sync_status_check" CHECK (("sync_status" = ANY (ARRAY['synced'::"text", 'pending'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."collections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."custom_domains" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "is_verified" boolean DEFAULT false,
    "ssl_status" "text" DEFAULT 'pending'::"text",
    "verification_token" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."custom_domains" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."custom_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "config" "jsonb" DEFAULT '{}'::"jsonb",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."custom_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "type" character varying(50) NOT NULL,
    "subject" character varying(255),
    "message" "text" NOT NULL,
    "rating" integer,
    "status" character varying(50) DEFAULT 'new'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    CONSTRAINT "customer_feedback_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."customer_feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "title" character varying(255) NOT NULL,
    "message" "text" NOT NULL,
    "type" character varying(50) NOT NULL,
    "is_read" boolean DEFAULT false,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "read_at" timestamp with time zone
);


ALTER TABLE "public"."customer_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_support_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "subject" character varying(255) NOT NULL,
    "message" "text" NOT NULL,
    "status" character varying(50) DEFAULT 'open'::character varying,
    "priority" character varying(50) DEFAULT 'normal'::character varying,
    "assigned_to" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "resolved_at" timestamp with time zone,
    "org_id" "uuid"
);


ALTER TABLE "public"."customer_support_tickets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_ticket_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ticket_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."customer_ticket_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."data_exports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "type" "text" DEFAULT 'full_backup'::"text" NOT NULL,
    "format" "text" DEFAULT 'json'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "filters" "jsonb" DEFAULT '{}'::"jsonb",
    "file_url" "text",
    "file_size" bigint,
    "error_message" "text",
    "created_by" "uuid",
    "completed_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "data_exports_format_check" CHECK (("format" = ANY (ARRAY['json'::"text", 'csv'::"text", 'xlsx'::"text", 'pdf'::"text"]))),
    CONSTRAINT "data_exports_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text", 'expired'::"text"]))),
    CONSTRAINT "data_exports_type_check" CHECK (("type" = ANY (ARRAY['full_backup'::"text", 'members'::"text", 'loans'::"text", 'transactions'::"text", 'savings'::"text", 'custom'::"text"])))
);


ALTER TABLE "public"."data_exports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."duty_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "start_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "end_time" timestamp with time zone,
    "start_lat" numeric,
    "start_lng" numeric,
    "end_lat" numeric,
    "end_lng" numeric,
    "duration_minutes" integer,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "duty_sessions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'completed'::"text", 'abandoned'::"text"])))
);


ALTER TABLE "public"."duty_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."email_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "template_key" "text" NOT NULL,
    "subject" "text",
    "body" "text",
    "variables" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."email_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."emi_schedule" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "loan_id" "uuid",
    "installment_number" integer NOT NULL,
    "due_date" "date" NOT NULL,
    "emi_amount" numeric(15,2) NOT NULL,
    "principal" numeric(15,2) NOT NULL,
    "interest" numeric(15,2) NOT NULL,
    "balance_after" numeric(15,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "paid_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "emi_number" integer,
    "paid_on" timestamp with time zone,
    "payment_mode" "text",
    "transaction_id" "uuid",
    "penalty_amount" numeric(15,2) DEFAULT 0,
    "penalty_paid" boolean DEFAULT false,
    "org_id" "uuid",
    "member_id" "uuid",
    "period" integer,
    "emi" numeric(12,2),
    "is_paid" boolean DEFAULT false,
    "is_overdue" boolean DEFAULT false,
    "penalty" numeric(12,2) DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "amount_paid" numeric(12,2) DEFAULT 0,
    CONSTRAINT "emi_schedule_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'overdue'::"text", 'waived'::"text", 'upcoming'::"text", 'frozen'::"text"])))
);


ALTER TABLE "public"."emi_schedule" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_flags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_enabled" boolean DEFAULT false,
    "rollout_percentage" integer DEFAULT 100,
    "target_orgs" "uuid"[] DEFAULT '{}'::"uuid"[],
    "target_roles" "text"[] DEFAULT '{}'::"text"[],
    "config" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."feature_flags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feature_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "user_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'submitted'::"text",
    "votes" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."feature_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."help_articles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "content" "text",
    "category" "text",
    "is_published" boolean DEFAULT false,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."help_articles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."integrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "config" "jsonb" DEFAULT '{}'::"jsonb",
    "credentials" "jsonb" DEFAULT '{}'::"jsonb",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."integrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "subscription_id" "uuid",
    "amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "invoice_number" "text",
    "due_date" "date",
    "paid_at" timestamp with time zone,
    "invoice_pdf" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "invoices_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'overdue'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."loan_schedules" WITH ("security_invoker"='true') AS
 SELECT "id",
    "loan_id",
    "installment_number" AS "period",
    "due_date",
    "emi_amount" AS "emi",
    "principal",
    "interest",
    "balance_after" AS "balance",
    ("status" = 'paid'::"text") AS "is_paid",
    ("status" = 'overdue'::"text") AS "is_overdue",
    "paid_on",
    "payment_mode",
    "penalty_amount" AS "penalty",
    "penalty_paid",
    "org_id",
    "created_at",
    "updated_at"
   FROM "public"."emi_schedule";


ALTER VIEW "public"."loan_schedules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."loan_statements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "loan_id" "uuid" NOT NULL,
    "statement_ref" "text" NOT NULL,
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "variant" "text" NOT NULL,
    "format" "text" NOT NULL,
    "file_path" "text" NOT NULL,
    "file_size_bytes" integer,
    "sha256_hash" "text" NOT NULL,
    "generated_by" "uuid",
    "generated_by_name" "text",
    "generated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "loan_statements_format_check" CHECK (("format" = ANY (ARRAY['pdf'::"text", 'excel'::"text", 'csv'::"text"]))),
    CONSTRAINT "loan_statements_variant_check" CHECK (("variant" = ANY (ARRAY['fullSchedule'::"text", 'activityOnly'::"text", 'taxStatement'::"text"])))
);


ALTER TABLE "public"."loan_statements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."loans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "loan_number" "text",
    "customer_id" "uuid",
    "staff_id" "uuid",
    "amount" numeric(15,2) NOT NULL,
    "interest_rate" numeric(10,2) NOT NULL,
    "tenure_months" integer NOT NULL,
    "emi_amount" numeric(15,2) NOT NULL,
    "total_interest" numeric(15,2) DEFAULT 0,
    "total_repayable" numeric(15,2) NOT NULL,
    "outstanding_balance" numeric(15,2) NOT NULL,
    "interest_type" "text" DEFAULT 'flat'::"text",
    "frequency" "text" DEFAULT 'monthly'::"text",
    "collection_type" "text" DEFAULT 'door_to_door'::"text",
    "disbursement_date" "date",
    "first_emi_date" "date",
    "first_installment_date" "date" NOT NULL,
    "status" "text" DEFAULT 'active'::"text",
    "purpose" "text",
    "remarks" "text",
    "created_by" "text",
    "approved_by" "text",
    "rejected_by" "text",
    "rejection_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "agent_id" "uuid",
    "member_name" "text",
    "member_id" "uuid",
    "outstanding_amount" numeric(12,2),
    "emi" numeric(12,2),
    "start_date" "date",
    "paid_emis" integer DEFAULT 0,
    "total_emis" integer,
    "branch_id" "uuid",
    "plan_id" "uuid",
    "interest_mode" "text" DEFAULT 'rate'::"text",
    "interest_amount" numeric(12,2) DEFAULT 0,
    "interest_basis" "text" DEFAULT 'monthly'::"text",
    "tenure_value" integer,
    "tenure_unit" "text" DEFAULT 'months'::"text",
    "interest_rate_basis" "text" DEFAULT 'monthly'::"text",
    "interest" numeric(12,2) DEFAULT 0,
    "principal" numeric(12,2) DEFAULT 0,
    "end_date" "date",
    "closed_date" "date",
    "closed_reason" "text",
    "loan_purpose" "text",
    "processing_fee" numeric(12,2) DEFAULT 0,
    "processing_fee_type" "text" DEFAULT 'flat'::"text",
    "grace_period_days" integer DEFAULT 0,
    "disbursement_method" "text",
    "disbursement_reference" "text",
    "internal_notes" "text",
    "assigned_collector_id" "uuid",
    "penalty_rate" numeric(10,2) DEFAULT 0,
    "penalty_type" "text" DEFAULT 'flat'::"text",
    "allow_prepayment" boolean DEFAULT true,
    "prepayment_penalty" numeric(10,2) DEFAULT 0,
    "guarantor_id" "uuid",
    "collateral_type" "text",
    "collateral_description" "text",
    "collateral_value" numeric(12,2),
    "insurance_premium" numeric(12,2) DEFAULT 0,
    "disbursed_amount" numeric(12,2),
    "last_payment_date" "date",
    "freeze_enabled" boolean DEFAULT false,
    "frozen_count" integer DEFAULT 0,
    CONSTRAINT "loans_collection_type_check" CHECK ((("collection_type" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text"])) OR ("collection_type" IS NULL))),
    CONSTRAINT "loans_frequency_check" CHECK (("frequency" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text"]))),
    CONSTRAINT "loans_interest_basis_check" CHECK (("interest_basis" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text", 'on_principal'::"text", 'onPrincipal'::"text"]))),
    CONSTRAINT "loans_interest_mode_check" CHECK (("interest_mode" = ANY (ARRAY['rate'::"text", 'amount'::"text"]))),
    CONSTRAINT "loans_interest_rate_basis_check" CHECK (("interest_rate_basis" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text", 'on_principal'::"text", 'onPrincipal'::"text"]))),
    CONSTRAINT "loans_interest_type_check" CHECK (("interest_type" = ANY (ARRAY['flat'::"text", 'reducingBalance'::"text", 'reducing_balance'::"text"]))),
    CONSTRAINT "loans_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'pending'::"text", 'approved'::"text", 'active'::"text", 'closed'::"text", 'rejected'::"text", 'defaultStatus'::"text", 'defaulted'::"text", 'restructured'::"text"]))),
    CONSTRAINT "loans_tenure_unit_check" CHECK (("tenure_unit" = ANY (ARRAY['days'::"text", 'weeks'::"text", 'months'::"text", 'years'::"text"])))
);


ALTER TABLE "public"."loans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."maintenance_windows" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "scheduled_start" timestamp with time zone NOT NULL,
    "scheduled_end" timestamp with time zone NOT NULL,
    "is_active" boolean DEFAULT false,
    "affected_services" "text"[] DEFAULT '{}'::"text"[],
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."maintenance_windows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "kyc_status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "gps_lat" numeric(10,8),
    "gps_lng" numeric(11,8),
    "gps_address" "text",
    "area" "text",
    "village" "text",
    "pincode" "text",
    "full_name" "text",
    "phone" "text",
    "member_id" "text",
    "shop_name" "text",
    "business_type" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "shop_photo_url" "text",
    "active_loans" integer DEFAULT 0,
    "total_savings" numeric(12,2) DEFAULT 0,
    "agent_id" "uuid",
    "branch_id" "uuid",
    "address" "text",
    "pan" "text",
    "aadhar" "text",
    "city" "text",
    "state" "text",
    "email" "text",
    "status" "text" DEFAULT 'active'::"text",
    "father_name" "text",
    "sms_enabled" boolean DEFAULT true,
    "profile_photo_url" "text",
    CONSTRAINT "members_kyc_status_check" CHECK (("kyc_status" = ANY (ARRAY['pending'::"text", 'verified'::"text", 'rejected'::"text"]))),
    CONSTRAINT "members_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."offline_sync_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "action_type" "text" NOT NULL,
    "entity_table" "text" NOT NULL,
    "entity_id" "text",
    "payload" "jsonb",
    "status" "text" DEFAULT 'pending'::"text",
    "retry_count" integer DEFAULT 0,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "processed_at" timestamp with time zone,
    CONSTRAINT "offline_sync_queue_action_type_check" CHECK (("action_type" = ANY (ARRAY['insert'::"text", 'update'::"text", 'delete'::"text"]))),
    CONSTRAINT "offline_sync_queue_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."offline_sync_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."org_branding" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "logo_url" "text",
    "logo_dark_url" "text",
    "primary_color" "text",
    "accent_color" "text",
    "favicon_url" "text",
    "tagline" "text",
    "website" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."org_branding" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."org_invitations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "branch_id" "uuid",
    "invited_by" "uuid",
    "token" "text" DEFAULT "encode"("extensions"."gen_random_bytes"(32), 'hex'::"text") NOT NULL,
    "personal_message" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "expires_at" timestamp with time zone DEFAULT ("now"() + '7 days'::interval),
    "accepted_at" timestamp with time zone,
    "accepted_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "message" "text",
    CONSTRAINT "org_invitations_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'manager'::"text", 'fieldStaff'::"text", 'accountant'::"text"]))),
    CONSTRAINT "org_invitations_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'expired'::"text", 'revoked'::"text"])))
);


ALTER TABLE "public"."org_invitations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."org_metrics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "metric_key" "text" NOT NULL,
    "metric_value" numeric DEFAULT 0,
    "period_start" timestamp with time zone,
    "period_end" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."org_metrics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."org_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."org_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_health_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "score_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "overall_score" integer DEFAULT 0,
    "collection_efficiency_score" integer DEFAULT 0,
    "member_growth_score" integer DEFAULT 0,
    "staff_productivity_score" integer DEFAULT 0,
    "financial_health_score" integer DEFAULT 0,
    "compliance_score" integer DEFAULT 0,
    "metrics" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."organization_health_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "domain" "text",
    "logo_url" "text",
    "primary_color" "text" DEFAULT '#6366F1'::"text",
    "status" "text" DEFAULT 'active'::"text",
    "max_branches" integer DEFAULT 10,
    "max_staff" integer DEFAULT 20,
    "max_members" integer DEFAULT 500,
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "trial_ends_at" timestamp with time zone,
    "created_by" "uuid",
    "display_name" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "gst_number" "text",
    "phone" "text",
    "email" "text",
    "brand_color" "text" DEFAULT '#1976D2'::"text",
    "icon_preset" "text" DEFAULT 'default'::"text",
    "plan" "text" DEFAULT 'free'::"text",
    CONSTRAINT "chk_icon_preset" CHECK (("icon_preset" = ANY (ARRAY['default'::"text", 'bank_blue'::"text", 'savings_green'::"text", 'micro_orange'::"text", 'trust_purple'::"text", 'field_teal'::"text", 'future_swarupnagar'::"text"]))),
    CONSTRAINT "organizations_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'suspended'::"text", 'trial'::"text"])))
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."icon_preset" IS 'Preset launcher icon theme ID. Valid values: default, bank_blue, savings_green, micro_orange, trust_purple, field_teal';



CREATE OR REPLACE VIEW "public"."overdue_loans_view" AS
 SELECT DISTINCT "l"."id",
    "l"."loan_number",
    "l"."customer_id",
    "l"."staff_id",
    "l"."amount",
    "l"."interest_rate",
    "l"."tenure_months",
    "l"."emi_amount",
    "l"."total_interest",
    "l"."total_repayable",
    "l"."outstanding_balance",
    "l"."interest_type",
    "l"."frequency",
    "l"."collection_type",
    "l"."disbursement_date",
    "l"."first_emi_date",
    "l"."first_installment_date",
    "l"."status",
    "l"."purpose",
    "l"."remarks",
    "l"."created_by",
    "l"."approved_by",
    "l"."rejected_by",
    "l"."rejection_reason",
    "l"."created_at",
    "l"."updated_at",
    "l"."org_id",
    "l"."agent_id",
    "l"."member_name",
    "l"."member_id",
    "l"."outstanding_amount",
    "l"."emi",
    "l"."start_date",
    "l"."paid_emis",
    "l"."total_emis",
    "l"."branch_id",
    "l"."plan_id",
    "l"."interest_mode",
    "l"."interest_amount",
    "l"."interest_basis",
    "l"."tenure_value",
    "l"."tenure_unit",
    "l"."interest_rate_basis",
    "l"."interest",
    "l"."principal",
    "l"."end_date",
    "l"."closed_date",
    "l"."closed_reason",
    "l"."loan_purpose",
    "l"."processing_fee",
    "l"."processing_fee_type",
    "l"."grace_period_days",
    "l"."disbursement_method",
    "l"."disbursement_reference",
    "l"."internal_notes",
    "l"."assigned_collector_id",
    "l"."penalty_rate",
    "l"."penalty_type",
    "l"."allow_prepayment",
    "l"."prepayment_penalty",
    "l"."guarantor_id",
    "l"."collateral_type",
    "l"."collateral_description",
    "l"."collateral_value",
    "l"."insurance_premium",
    "l"."disbursed_amount"
   FROM ("public"."loans" "l"
     JOIN "public"."emi_schedule" "es" ON (("es"."loan_id" = "l"."id")))
  WHERE (("l"."status" = 'active'::"text") AND ("es"."due_date" < CURRENT_DATE) AND (("es"."status" IS NULL) OR ("es"."status" <> ALL (ARRAY['paid'::"text", 'waived'::"text"]))));


ALTER VIEW "public"."overdue_loans_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_methods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "type" "text" DEFAULT 'card'::"text" NOT NULL,
    "last_four" "text",
    "brand" "text",
    "is_default" boolean DEFAULT false,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "invoice_id" "uuid",
    "amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "payment_method_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pending_approvals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "branch_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "member_id" "uuid",
    "requested_by" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "pending_approvals_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"]))),
    CONSTRAINT "pending_approvals_type_check" CHECK (("type" = ANY (ARRAY['loan'::"text", 'withdrawal'::"text", 'kyc'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."pending_approvals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_activity_feed" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "activity_type" "text" NOT NULL,
    "activity_data" "jsonb" DEFAULT '{}'::"jsonb",
    "org_id" "uuid",
    "branch_id" "uuid",
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_activity_feed" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "text" DEFAULT 'info'::"text",
    "target_audience" "text" DEFAULT 'all'::"text",
    "target_orgs" "uuid"[] DEFAULT '{}'::"uuid"[],
    "is_active" boolean DEFAULT true,
    "show_from" timestamp with time zone,
    "show_until" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_daily_metrics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "metric_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "total_organizations" integer DEFAULT 0,
    "active_organizations" integer DEFAULT 0,
    "total_users" integer DEFAULT 0,
    "active_users" integer DEFAULT 0,
    "total_branches" integer DEFAULT 0,
    "total_members" integer DEFAULT 0,
    "total_loans" integer DEFAULT 0,
    "total_loan_amount" numeric DEFAULT 0,
    "total_collections" numeric DEFAULT 0,
    "total_savings" numeric DEFAULT 0,
    "mrr" numeric DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_daily_metrics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_revenue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "amount" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'INR'::"text",
    "payment_method" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "invoice_number" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_revenue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "value" "jsonb",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platform_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "full_name" "text",
    "email" "text",
    "phone" "text",
    "pan" "text",
    "aadhar" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "role" "text" DEFAULT 'retailMember'::"text",
    "employee_id" "text",
    "assigned_zone" "text",
    "date_of_birth" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "branch_id" "uuid",
    "staff_code" "text",
    "status" "text" DEFAULT 'active'::"text",
    "avatar_url" "text",
    "member_id" "text",
    "is_2fa_enabled" boolean DEFAULT false,
    "is_active" boolean DEFAULT true,
    "last_login" timestamp with time zone,
    "is_on_duty" boolean DEFAULT false,
    "father_name" "text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text", 'customer'::"text", 'fieldStaff'::"text", 'retailMember'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."referrals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referrer_org_id" "uuid",
    "referred_org_id" "uuid",
    "code" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "reward_amount" numeric DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."referrals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."savings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "account_number" "text",
    "balance" numeric(15,2) DEFAULT 0,
    "account_type" "text" DEFAULT 'savings'::"text",
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "plan_name" "text",
    "target_amount" numeric(12,2),
    "monthly_deposit" numeric(12,2),
    "maturity_date" "date",
    "member_id" "uuid",
    CONSTRAINT "savings_account_type_check" CHECK (("account_type" = ANY (ARRAY['savings'::"text", 'fixed_deposit'::"text", 'recurring_deposit'::"text", 'current'::"text"]))),
    CONSTRAINT "savings_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'closed'::"text", 'frozen'::"text"])))
);


ALTER TABLE "public"."savings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."savings_collections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "savings_plan_id" "uuid",
    "member_id" "uuid",
    "staff_id" "uuid",
    "member_name" "text",
    "member_phone" "text",
    "amount_expected" numeric(12,2) NOT NULL,
    "amount_collected" numeric(12,2) NOT NULL,
    "variance" numeric(12,2) GENERATED ALWAYS AS (("amount_collected" - "amount_expected")) STORED,
    "is_partial" boolean DEFAULT false,
    "is_advance" boolean DEFAULT false,
    "payment_mode" "text" DEFAULT 'cash'::"text",
    "penalty_amount" numeric(12,2) DEFAULT 0,
    "gps_lat" numeric(10,8),
    "gps_lng" numeric(11,8),
    "collection_date" "date" DEFAULT CURRENT_DATE,
    "sync_status" "text" DEFAULT 'synced'::"text",
    "local_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "collected_by_user_id" "uuid",
    "collected_by_name" "text",
    "collected_by_role" "text",
    "collected_at" timestamp with time zone,
    "entered_by_user_id" "uuid",
    "entered_by_name" "text",
    "collection_method" "text",
    "transaction_id" "uuid",
    "collection_time" timestamp with time zone,
    CONSTRAINT "savings_collections_collected_by_role_check" CHECK ((("collected_by_role" IS NULL) OR ("collected_by_role" = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text", 'fieldStaff'::"text", 'customer'::"text", 'retailMember'::"text"])))),
    CONSTRAINT "savings_collections_collection_method_check" CHECK ((("collection_method" IS NULL) OR ("collection_method" = ANY (ARRAY['agent_field'::"text", 'branch_counter'::"text", 'online'::"text", 'auto_debit'::"text", 'other'::"text"])))),
    CONSTRAINT "savings_collections_payment_mode_check" CHECK (("payment_mode" = ANY (ARRAY['cash'::"text", 'upi'::"text", 'bank_transfer'::"text", 'cheque'::"text", 'card'::"text"]))),
    CONSTRAINT "savings_collections_sync_status_check" CHECK (("sync_status" = ANY (ARRAY['synced'::"text", 'pending'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."savings_collections" OWNER TO "postgres";


COMMENT ON COLUMN "public"."savings_collections"."transaction_id" IS 'Links to the transaction record created for this collection. Used for precise deletion.';



CREATE OR REPLACE VIEW "public"."savings_deposits" WITH ("security_invoker"='true') AS
 SELECT "id",
    "savings_plan_id" AS "account_id",
    "member_id",
    "staff_id",
    "amount_collected" AS "amount",
    "collection_date" AS "deposit_date",
    "payment_mode" AS "deposit_mode",
    "created_at"
   FROM "public"."savings_collections";


ALTER VIEW "public"."savings_deposits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."savings_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "member_id" "uuid",
    "plan_name" "text" DEFAULT 'Recurring Deposit'::"text",
    "target_amount" numeric(15,2) NOT NULL,
    "current_amount" numeric(15,2) DEFAULT 0,
    "monthly_deposit" numeric(15,2) NOT NULL,
    "interest_rate" numeric(10,2) DEFAULT 0,
    "maturity_amount" numeric(15,2) NOT NULL,
    "maturity_date" "date" NOT NULL,
    "collection_type" "text" DEFAULT 'monthly'::"text",
    "premature_penalty" numeric(10,2) DEFAULT 0,
    "total_installments" integer DEFAULT 0,
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid",
    "next_due_date" "date",
    "collection_day_of_week" integer,
    "collection_day_of_month" integer,
    "start_date" "date" DEFAULT CURRENT_DATE,
    "tenure_unit" "text" DEFAULT 'months'::"text",
    "tenure" integer DEFAULT 12,
    "opening_balance" numeric DEFAULT 0,
    "total_return_amount" numeric DEFAULT 0,
    "interest_amount" numeric DEFAULT 0,
    "installments_paid" integer DEFAULT 0,
    "last_payment_date" "date",
    "freeze_enabled" boolean DEFAULT false,
    "frozen_count" integer DEFAULT 0,
    "frozen_dates" "text"[] DEFAULT '{}'::"text"[],
    CONSTRAINT "savings_plans_collection_type_check" CHECK (("collection_type" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text"]))),
    CONSTRAINT "savings_plans_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'paused'::"text", 'matured'::"text", 'completed'::"text", 'closed'::"text", 'cancelled'::"text", 'withdrawn'::"text"])))
);


ALTER TABLE "public"."savings_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sms_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "collection_id" "uuid",
    "member_id" "uuid",
    "member_phone" "text" NOT NULL,
    "message" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "error_message" "text",
    "platform" "text",
    "sent_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "collector_name" "text",
    "recipient_name" "text",
    "recipient_phone" "text",
    CONSTRAINT "sms_notifications_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text", 'skipped'::"text"])))
);


ALTER TABLE "public"."sms_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "icon" "text",
    "points" integer DEFAULT 0,
    "category" "text",
    "is_unlocked" boolean DEFAULT false,
    "unlocked_at" timestamp with time zone,
    "progress" numeric(5,2) DEFAULT 0,
    "target" numeric(5,2) DEFAULT 1,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."staff_achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_breaks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "break_start" timestamp with time zone NOT NULL,
    "break_end" timestamp with time zone,
    "duration_minutes" integer,
    "break_type" "text" DEFAULT 'lunch'::"text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."staff_breaks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_points" (
    "staff_id" "uuid" NOT NULL,
    "total_points" integer DEFAULT 0,
    "level" integer DEFAULT 1,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."staff_points" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "staff_code" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "email" "text",
    "role" "text" DEFAULT 'collector'::"text" NOT NULL,
    "branch_id" "uuid",
    "status" "text" DEFAULT 'active'::"text",
    "assigned_areas" "text"[],
    "shift" "text" DEFAULT 'morning'::"text",
    "hire_date" "date",
    "daily_collection_target" numeric(12,2) DEFAULT 50000.00,
    "monthly_collection_target" numeric(12,2) DEFAULT 1500000.00,
    "supervisor_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "staff_profiles_role_check" CHECK (("role" = ANY (ARRAY['collector'::"text", 'supervisor'::"text", 'branch_manager'::"text", 'area_manager'::"text"]))),
    CONSTRAINT "staff_profiles_shift_check" CHECK (("shift" = ANY (ARRAY['morning'::"text", 'evening'::"text", 'full_day'::"text"]))),
    CONSTRAINT "staff_profiles_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text", 'on_leave'::"text"])))
);


ALTER TABLE "public"."staff_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_streaks" (
    "staff_id" "uuid" NOT NULL,
    "current_streak" integer DEFAULT 0,
    "longest_streak" integer DEFAULT 0,
    "last_collection_date" "date",
    "total_collections" integer DEFAULT 0,
    "total_amount_collected" numeric(14,2) DEFAULT 0,
    "perfect_days" integer DEFAULT 0,
    "badges" "jsonb" DEFAULT '[]'::"jsonb",
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "org_id" "uuid",
    "last_activity_date" "date",
    "streak_start_date" "date"
);


ALTER TABLE "public"."staff_streaks" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."staff_leaderboard_view" AS
 SELECT "sp"."id" AS "staff_id",
    "sp"."full_name" AS "staff_name",
    COALESCE("spoints"."total_points", 0) AS "total_points",
    COALESCE("sstreak"."current_streak", 0) AS "current_streak",
    "sp"."branch_id",
    "sp"."org_id"
   FROM (("public"."staff_profiles" "sp"
     LEFT JOIN "public"."staff_points" "spoints" ON (("spoints"."staff_id" = "sp"."id")))
     LEFT JOIN "public"."staff_streaks" "sstreak" ON (("sstreak"."staff_id" = "sp"."id")))
  WHERE ("sp"."status" = 'active'::"text");


ALTER VIEW "public"."staff_leaderboard_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "latitude" numeric(10,8) NOT NULL,
    "longitude" numeric(11,8) NOT NULL,
    "accuracy" numeric(10,2),
    "altitude" numeric(10,2),
    "speed" numeric(10,2),
    "heading" numeric(10,2),
    "activity_type" "text",
    "battery_level" numeric(5,2),
    "is_charging" boolean,
    "recorded_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "org_id" "uuid",
    "is_active" boolean DEFAULT false,
    "session_id" "text",
    "address" "text",
    "branch_id" "uuid"
);


ALTER TABLE "public"."staff_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "text" DEFAULT 'info'::"text",
    "priority" "text" DEFAULT 'normal'::"text",
    "action_data" "jsonb",
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "staff_notifications_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "staff_notifications_type_check" CHECK (("type" = ANY (ARRAY['target'::"text", 'overdue'::"text", 'sync'::"text", 'alert'::"text", 'reminder'::"text", 'system'::"text", 'upi'::"text"])))
);


ALTER TABLE "public"."staff_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_points_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "points" integer NOT NULL,
    "reason" "text",
    "reference_type" "text",
    "reference_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."staff_points_log" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."staff_today_summary" AS
 SELECT "staff_id",
    "count"("id") AS "collections_count",
    COALESCE("sum"("amount_collected"), (0)::numeric) AS "total_collected",
    COALESCE("sum"("amount_expected"), (0)::numeric) AS "total_expected"
   FROM "public"."collections" "c"
  WHERE ("collection_date" = CURRENT_DATE)
  GROUP BY "staff_id";


ALTER VIEW "public"."staff_today_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_wallet" (
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "cash_in_hand" numeric(12,2) DEFAULT 0,
    "digital_balance" numeric(12,2) DEFAULT 0,
    "total_collected_today" numeric(12,2) DEFAULT 0,
    "total_deposited_today" numeric(12,2) DEFAULT 0,
    "safe_limit" numeric(12,2) DEFAULT 50000.00,
    "is_over_limit" boolean GENERATED ALWAYS AS (("cash_in_hand" > "safe_limit")) STORED,
    "last_updated" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."staff_wallet" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscription_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "price_monthly" numeric DEFAULT 0,
    "price_yearly" numeric DEFAULT 0,
    "max_users" integer DEFAULT 10,
    "max_branches" integer DEFAULT 1,
    "max_loans" integer DEFAULT 100,
    "features" "jsonb" DEFAULT '[]'::"jsonb",
    "is_active" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."subscription_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "plan_id" "uuid",
    "status" "text" DEFAULT 'active'::"text",
    "billing_cycle" "text" DEFAULT 'monthly'::"text",
    "current_period_start" timestamp with time zone DEFAULT "now"(),
    "current_period_end" timestamp with time zone DEFAULT ("now"() + '30 days'::interval),
    "cancel_at_period_end" boolean DEFAULT false,
    "cancelled_at" timestamp with time zone,
    "trial_start" timestamp with time zone,
    "trial_end" timestamp with time zone,
    "payment_method_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "subscriptions_billing_cycle_check" CHECK (("billing_cycle" = ANY (ARRAY['monthly'::"text", 'yearly'::"text"]))),
    CONSTRAINT "subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'cancelled'::"text", 'expired'::"text", 'suspended'::"text", 'trial'::"text"])))
);


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid",
    "user_id" "uuid",
    "subject" "text" NOT NULL,
    "description" "text",
    "category" "text" DEFAULT 'general'::"text",
    "priority" "text" DEFAULT 'normal'::"text",
    "status" "text" DEFAULT 'open'::"text",
    "assigned_to" "uuid",
    "messages" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "resolved_at" timestamp with time zone
);


ALTER TABLE "public"."support_tickets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sync_conflicts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "table_name" "text" NOT NULL,
    "record_id" "text",
    "local_data" "jsonb",
    "server_data" "jsonb",
    "resolution" "text" DEFAULT 'pending'::"text",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."sync_conflicts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "current_version_android" "text" DEFAULT '1.0.0'::"text" NOT NULL,
    "min_version_android" "text" DEFAULT '1.0.0'::"text" NOT NULL,
    "current_version_ios" "text" DEFAULT '1.0.0'::"text" NOT NULL,
    "min_version_ios" "text" DEFAULT '1.0.0'::"text" NOT NULL,
    "update_url_android" "text",
    "update_url_ios" "text",
    "update_message" "text" DEFAULT 'A new version is available. Please update to continue.'::"text",
    "is_under_maintenance" boolean DEFAULT false,
    "maintenance_message" "text" DEFAULT 'MicroFlow Pro is currently under maintenance. We will be back soon.'::"text",
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_by" "uuid"
);


ALTER TABLE "public"."system_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_error_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "level" "text" DEFAULT 'error'::"text",
    "message" "text",
    "stack_trace" "text",
    "context" "jsonb" DEFAULT '{}'::"jsonb",
    "resolved" boolean DEFAULT false,
    "resolved_by" "uuid",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."system_error_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "value" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "org_id" "uuid"
);


ALTER TABLE "public"."system_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_status" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "service" "text" NOT NULL,
    "status" "text" DEFAULT 'healthy'::"text",
    "latency_ms" integer,
    "checked_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."system_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "loan_id" "uuid",
    "savings_id" "uuid",
    "type" "text" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "reference_number" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "payment_mode" "text",
    "entered_at" timestamp with time zone,
    "org_id" "uuid",
    "member_id" "uuid",
    "member_name" "text",
    "description" "text",
    "agent_id" "uuid",
    "staff_id" "uuid",
    "gps_lat" numeric(10,8),
    "gps_lng" numeric(11,8),
    "transaction_date" "date",
    "transaction_time" timestamp with time zone,
    "sync_status" "text" DEFAULT 'synced'::"text",
    "collected_by_user_id" "uuid",
    "collected_by_name" "text",
    "collected_by_role" "text",
    "collected_at" timestamp with time zone,
    "entered_by_user_id" "uuid",
    "entered_by_name" "text",
    "collection_method" "text",
    CONSTRAINT "transactions_collected_by_role_check" CHECK ((("collected_by_role" IS NULL) OR ("collected_by_role" = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text", 'fieldStaff'::"text", 'customer'::"text", 'retailMember'::"text"])))),
    CONSTRAINT "transactions_collection_method_check" CHECK ((("collection_method" IS NULL) OR ("collection_method" = ANY (ARRAY['agent_field'::"text", 'branch_counter'::"text", 'online'::"text", 'auto_debit'::"text", 'other'::"text"])))),
    CONSTRAINT "transactions_type_check" CHECK (("type" = ANY (ARRAY['loanDisbursement'::"text", 'emiPayment'::"text", 'savingsDeposit'::"text", 'savingsWithdrawal'::"text", 'penalty'::"text", 'staffCashDeposit'::"text", 'other'::"text", 'collection'::"text", 'deposit'::"text", 'withdrawal'::"text"])))
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."upi_payment_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "member_id" "uuid",
    "loan_id" "uuid",
    "savings_plan_id" "uuid",
    "emi_schedule_id" "uuid",
    "amount" numeric(12,2) NOT NULL,
    "upi_vpa" "text" NOT NULL,
    "transaction_ref" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "confirmed_by" "uuid",
    "confirmed_at" timestamp with time zone,
    "rejection_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "installment_date" "date",
    CONSTRAINT "upi_payment_requests_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "upi_payment_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."upi_payment_requests" OWNER TO "postgres";


COMMENT ON COLUMN "public"."upi_payment_requests"."installment_date" IS 'The due date this payment is covering â€” applies to both loan EMIs and savings installments.';



CREATE TABLE IF NOT EXISTS "public"."usage_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "metric" "text" NOT NULL,
    "value" integer DEFAULT 0,
    "period_start" timestamp with time zone,
    "period_end" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."usage_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."video_tutorials" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "video_url" "text" NOT NULL,
    "thumbnail_url" "text",
    "duration_seconds" integer,
    "category" "text",
    "sort_order" integer DEFAULT 0,
    "is_published" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."video_tutorials" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."visit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "member_id" "uuid",
    "org_id" "uuid" NOT NULL,
    "check_in_time" timestamp with time zone NOT NULL,
    "check_out_time" timestamp with time zone,
    "check_in_lat" numeric(10,8),
    "check_in_lng" numeric(11,8),
    "check_out_lat" numeric(10,8),
    "check_out_lng" numeric(11,8),
    "duration_minutes" integer GENERATED ALWAYS AS ((EXTRACT(epoch FROM ("check_out_time" - "check_in_time")) / (60)::numeric)) STORED,
    "purpose" "text",
    "outcome" "text",
    "notes" "text",
    "is_offline" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "customer_id" "uuid",
    "status" "text" DEFAULT 'in_progress'::"text"
);


ALTER TABLE "public"."visit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "direction" "text" NOT NULL,
    "payment_mode" "text" DEFAULT 'cash'::"text",
    "balance_before" numeric(12,2),
    "balance_after" numeric(12,2),
    "collection_id" "uuid",
    "reference" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "wallet_transactions_direction_check" CHECK (("direction" = ANY (ARRAY['in'::"text", 'out'::"text"]))),
    CONSTRAINT "wallet_transactions_type_check" CHECK (("type" = ANY (ARRAY['collection'::"text", 'deposit'::"text", 'withdrawal'::"text", 'adjustment'::"text", 'refund'::"text"])))
);


ALTER TABLE "public"."wallet_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhook_deliveries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "webhook_id" "uuid" NOT NULL,
    "event" "text" NOT NULL,
    "payload" "jsonb",
    "response_status" integer,
    "response_body" "text",
    "delivered_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."webhook_deliveries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhooks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "url" "text" NOT NULL,
    "events" "text"[] DEFAULT '{}'::"text"[],
    "is_active" boolean DEFAULT true,
    "secret" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."webhooks" OWNER TO "postgres";


ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_org_id_code_key" UNIQUE ("org_id", "code");



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_notes"
    ADD CONSTRAINT "admin_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."agent_areas"
    ADD CONSTRAINT "agent_areas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."api_usage_logs"
    ADD CONSTRAINT "api_usage_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_updates"
    ADD CONSTRAINT "app_updates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branch_targets"
    ADD CONSTRAINT "branch_targets_branch_id_month_year_key" UNIQUE ("branch_id", "month", "year");



ALTER TABLE ONLY "public"."branch_targets"
    ADD CONSTRAINT "branch_targets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_org_id_code_key" UNIQUE ("org_id", "code");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_deposits"
    ADD CONSTRAINT "cash_deposits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."collection_backdate_audit"
    ADD CONSTRAINT "collection_backdate_audit_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."collection_targets"
    ADD CONSTRAINT "collection_targets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."collection_targets"
    ADD CONSTRAINT "collection_targets_staff_id_period_type_target_date_key" UNIQUE ("staff_id", "period_type", "target_date");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."custom_domains"
    ADD CONSTRAINT "custom_domains_domain_key" UNIQUE ("domain");



ALTER TABLE ONLY "public"."custom_domains"
    ADD CONSTRAINT "custom_domains_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."custom_reports"
    ADD CONSTRAINT "custom_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_feedback"
    ADD CONSTRAINT "customer_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_notifications"
    ADD CONSTRAINT "customer_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_support_tickets"
    ADD CONSTRAINT "customer_support_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_ticket_messages"
    ADD CONSTRAINT "customer_ticket_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."data_exports"
    ADD CONSTRAINT "data_exports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."duty_sessions"
    ADD CONSTRAINT "duty_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."email_templates"
    ADD CONSTRAINT "email_templates_org_id_template_key_key" UNIQUE ("org_id", "template_key");



ALTER TABLE ONLY "public"."email_templates"
    ADD CONSTRAINT "email_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "emi_schedule_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feature_flags"
    ADD CONSTRAINT "feature_flags_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."feature_flags"
    ADD CONSTRAINT "feature_flags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feature_requests"
    ADD CONSTRAINT "feature_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."help_articles"
    ADD CONSTRAINT "help_articles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."integrations"
    ADD CONSTRAINT "integrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."loan_statements"
    ADD CONSTRAINT "loan_statements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_loan_number_key" UNIQUE ("loan_number");



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."maintenance_windows"
    ADD CONSTRAINT "maintenance_windows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_email_unique" UNIQUE ("email");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."offline_sync_queue"
    ADD CONSTRAINT "offline_sync_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."org_branding"
    ADD CONSTRAINT "org_branding_org_id_key" UNIQUE ("org_id");



ALTER TABLE ONLY "public"."org_branding"
    ADD CONSTRAINT "org_branding_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "org_invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "org_invitations_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."org_metrics"
    ADD CONSTRAINT "org_metrics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."org_settings"
    ADD CONSTRAINT "org_settings_org_id_key" UNIQUE ("org_id");



ALTER TABLE ONLY "public"."org_settings"
    ADD CONSTRAINT "org_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_health_scores"
    ADD CONSTRAINT "organization_health_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pending_approvals"
    ADD CONSTRAINT "pending_approvals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_activity_feed"
    ADD CONSTRAINT "platform_activity_feed_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_announcements"
    ADD CONSTRAINT "platform_announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_daily_metrics"
    ADD CONSTRAINT "platform_daily_metrics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_revenue"
    ADD CONSTRAINT "platform_revenue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_settings"
    ADD CONSTRAINT "platform_settings_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."platform_settings"
    ADD CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_unique" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."referrals"
    ADD CONSTRAINT "referrals_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."referrals"
    ADD CONSTRAINT "referrals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."savings"
    ADD CONSTRAINT "savings_account_number_key" UNIQUE ("account_number");



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "savings_collections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."savings"
    ADD CONSTRAINT "savings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."savings_plans"
    ADD CONSTRAINT "savings_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sms_notifications"
    ADD CONSTRAINT "sms_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_achievements"
    ADD CONSTRAINT "staff_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_breaks"
    ADD CONSTRAINT "staff_breaks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_locations"
    ADD CONSTRAINT "staff_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_notifications"
    ADD CONSTRAINT "staff_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_points_log"
    ADD CONSTRAINT "staff_points_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_points"
    ADD CONSTRAINT "staff_points_pkey" PRIMARY KEY ("staff_id");



ALTER TABLE ONLY "public"."staff_profiles"
    ADD CONSTRAINT "staff_profiles_org_id_staff_code_key" UNIQUE ("org_id", "staff_code");



ALTER TABLE ONLY "public"."staff_profiles"
    ADD CONSTRAINT "staff_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_streaks"
    ADD CONSTRAINT "staff_streaks_pkey" PRIMARY KEY ("staff_id");



ALTER TABLE ONLY "public"."staff_wallet"
    ADD CONSTRAINT "staff_wallet_pkey" PRIMARY KEY ("staff_id");



ALTER TABLE ONLY "public"."subscription_plans"
    ADD CONSTRAINT "subscription_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sync_conflicts"
    ADD CONSTRAINT "sync_conflicts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."system_config"
    ADD CONSTRAINT "system_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."system_error_logs"
    ADD CONSTRAINT "system_error_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."system_settings"
    ADD CONSTRAINT "system_settings_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."system_settings"
    ADD CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."system_status"
    ADD CONSTRAINT "system_status_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_reference_number_key" UNIQUE ("reference_number");



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usage_records"
    ADD CONSTRAINT "usage_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."video_tutorials"
    ADD CONSTRAINT "video_tutorials_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visit_logs"
    ADD CONSTRAINT "visit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_deliveries"
    ADD CONSTRAINT "webhook_deliveries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhooks"
    ADD CONSTRAINT "webhooks_pkey" PRIMARY KEY ("id");



CREATE INDEX "collection_backdate_audit_collection_id_idx" ON "public"."collection_backdate_audit" USING "btree" ("collection_id");



CREATE INDEX "collection_backdate_audit_org_id_created_at_idx" ON "public"."collection_backdate_audit" USING "btree" ("org_id", "created_at" DESC);



CREATE INDEX "collection_backdate_audit_performed_by_idx" ON "public"."collection_backdate_audit" USING "btree" ("performed_by");



CREATE INDEX "collections_is_backdated_idx" ON "public"."collections" USING "btree" ("org_id", "is_backdated") WHERE ("is_backdated" = true);



CREATE INDEX "idx_activity_logs_created_at" ON "public"."activity_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_activity_logs_org" ON "public"."activity_logs" USING "btree" ("org_id");



CREATE INDEX "idx_activity_logs_user_id" ON "public"."activity_logs" USING "btree" ("user_id");



CREATE INDEX "idx_admin_notes_author_profile" ON "public"."admin_notes" USING "btree" ("author_profile_id");



CREATE INDEX "idx_admin_notes_created" ON "public"."admin_notes" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_admin_notes_org" ON "public"."admin_notes" USING "btree" ("org_id");



CREATE INDEX "idx_admin_notes_user" ON "public"."admin_notes" USING "btree" ("user_profile_id");



CREATE INDEX "idx_announcements_org" ON "public"."announcements" USING "btree" ("org_id");



CREATE INDEX "idx_api_usage_logs_created" ON "public"."api_usage_logs" USING "btree" ("created_at");



CREATE INDEX "idx_audit_logs_action" ON "public"."audit_logs" USING "btree" ("action");



CREATE INDEX "idx_audit_logs_created" ON "public"."audit_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_audit_logs_entity" ON "public"."audit_logs" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_audit_logs_org" ON "public"."audit_logs" USING "btree" ("org_id");



CREATE INDEX "idx_audit_logs_user" ON "public"."audit_logs" USING "btree" ("user_id");



CREATE INDEX "idx_branch_targets_branch_month_year" ON "public"."branch_targets" USING "btree" ("branch_id", "month", "year");



CREATE INDEX "idx_branches_manager" ON "public"."branches" USING "btree" ("manager_id");



CREATE INDEX "idx_branches_org" ON "public"."branches" USING "btree" ("org_id");



CREATE INDEX "idx_branches_zone" ON "public"."branches" USING "btree" ("zone");



CREATE INDEX "idx_cash_deposits_org" ON "public"."cash_deposits" USING "btree" ("org_id");



CREATE INDEX "idx_collection_targets_org" ON "public"."collection_targets" USING "btree" ("org_id");



CREATE INDEX "idx_collections_branch" ON "public"."collections" USING "btree" ("branch_id");



CREATE INDEX "idx_collections_collected_at" ON "public"."collections" USING "btree" ("collected_at" DESC);



CREATE INDEX "idx_collections_collected_by_user" ON "public"."collections" USING "btree" ("collected_by_user_id");



CREATE INDEX "idx_collections_date" ON "public"."collections" USING "btree" ("collection_date");



CREATE INDEX "idx_collections_entered_by" ON "public"."collections" USING "btree" ("entered_by_user_id");



CREATE INDEX "idx_collections_loan" ON "public"."collections" USING "btree" ("loan_id");



CREATE INDEX "idx_collections_member" ON "public"."collections" USING "btree" ("member_id");



CREATE INDEX "idx_collections_org" ON "public"."collections" USING "btree" ("org_id");



CREATE INDEX "idx_collections_schedule" ON "public"."collections" USING "btree" ("loan_schedule_id");



CREATE INDEX "idx_collections_staff" ON "public"."collections" USING "btree" ("staff_id");



CREATE INDEX "idx_collections_transaction_id" ON "public"."collections" USING "btree" ("transaction_id");



CREATE INDEX "idx_customer_feedback_customer" ON "public"."customer_feedback" USING "btree" ("customer_id");



CREATE INDEX "idx_customer_feedback_org" ON "public"."customer_feedback" USING "btree" ("org_id");



CREATE INDEX "idx_customer_notifications_customer" ON "public"."customer_notifications" USING "btree" ("customer_id");



CREATE INDEX "idx_customer_support_tickets_customer" ON "public"."customer_support_tickets" USING "btree" ("customer_id");



CREATE INDEX "idx_customer_ticket_messages_ticket" ON "public"."customer_ticket_messages" USING "btree" ("ticket_id");



CREATE INDEX "idx_data_exports_created" ON "public"."data_exports" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_data_exports_created_by" ON "public"."data_exports" USING "btree" ("created_by");



CREATE INDEX "idx_data_exports_org" ON "public"."data_exports" USING "btree" ("org_id");



CREATE INDEX "idx_data_exports_status" ON "public"."data_exports" USING "btree" ("status");



CREATE INDEX "idx_duty_sessions_org" ON "public"."duty_sessions" USING "btree" ("org_id");



CREATE INDEX "idx_duty_sessions_org_status" ON "public"."duty_sessions" USING "btree" ("org_id", "status");



CREATE INDEX "idx_duty_sessions_staff" ON "public"."duty_sessions" USING "btree" ("staff_id");



CREATE INDEX "idx_duty_sessions_staff_status" ON "public"."duty_sessions" USING "btree" ("staff_id", "status");



CREATE INDEX "idx_duty_sessions_status" ON "public"."duty_sessions" USING "btree" ("status");



CREATE INDEX "idx_email_templates_org" ON "public"."email_templates" USING "btree" ("org_id");



CREATE INDEX "idx_emi_schedule_due_date" ON "public"."emi_schedule" USING "btree" ("due_date");



CREATE INDEX "idx_emi_schedule_loan_id" ON "public"."emi_schedule" USING "btree" ("loan_id");



CREATE INDEX "idx_emi_schedule_loan_status" ON "public"."emi_schedule" USING "btree" ("loan_id", "status");



CREATE INDEX "idx_emi_schedule_member" ON "public"."emi_schedule" USING "btree" ("member_id");



CREATE INDEX "idx_emi_schedule_org_id" ON "public"."emi_schedule" USING "btree" ("org_id");



CREATE INDEX "idx_emi_schedule_paid_date" ON "public"."emi_schedule" USING "btree" ("paid_date");



CREATE INDEX "idx_emi_schedule_status" ON "public"."emi_schedule" USING "btree" ("status");



CREATE INDEX "idx_emi_schedule_transaction" ON "public"."emi_schedule" USING "btree" ("transaction_id");



CREATE INDEX "idx_feature_flags_key" ON "public"."feature_flags" USING "btree" ("key");



CREATE INDEX "idx_integrations_org" ON "public"."integrations" USING "btree" ("org_id");



CREATE INDEX "idx_invitations_accepted_by" ON "public"."org_invitations" USING "btree" ("accepted_by");



CREATE INDEX "idx_invitations_branch" ON "public"."org_invitations" USING "btree" ("branch_id");



CREATE INDEX "idx_invitations_invited_by" ON "public"."org_invitations" USING "btree" ("invited_by");



CREATE INDEX "idx_loan_statements_generated_by" ON "public"."loan_statements" USING "btree" ("generated_by");



CREATE INDEX "idx_loan_statements_loan" ON "public"."loan_statements" USING "btree" ("loan_id", "generated_at" DESC);



CREATE INDEX "idx_loan_statements_org" ON "public"."loan_statements" USING "btree" ("org_id");



CREATE UNIQUE INDEX "idx_loan_statements_ref" ON "public"."loan_statements" USING "btree" ("statement_ref");



CREATE INDEX "idx_loans_agent" ON "public"."loans" USING "btree" ("agent_id");



CREATE INDEX "idx_loans_assigned_collector" ON "public"."loans" USING "btree" ("assigned_collector_id");



CREATE INDEX "idx_loans_branch" ON "public"."loans" USING "btree" ("branch_id");



CREATE INDEX "idx_loans_created_at" ON "public"."loans" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_loans_customer" ON "public"."loans" USING "btree" ("customer_id");



CREATE INDEX "idx_loans_customer_id" ON "public"."loans" USING "btree" ("customer_id");



CREATE INDEX "idx_loans_disbursement" ON "public"."loans" USING "btree" ("disbursement_method");



CREATE INDEX "idx_loans_guarantor" ON "public"."loans" USING "btree" ("guarantor_id");



CREATE INDEX "idx_loans_loan_number" ON "public"."loans" USING "btree" ("loan_number");



CREATE INDEX "idx_loans_member" ON "public"."loans" USING "btree" ("member_id");



CREATE INDEX "idx_loans_org" ON "public"."loans" USING "btree" ("org_id");



CREATE INDEX "idx_loans_purpose" ON "public"."loans" USING "btree" ("loan_purpose");



CREATE INDEX "idx_loans_staff" ON "public"."loans" USING "btree" ("staff_id");



CREATE INDEX "idx_loans_status" ON "public"."loans" USING "btree" ("status");



CREATE INDEX "idx_members_branch" ON "public"."members" USING "btree" ("branch_id");



CREATE INDEX "idx_members_org" ON "public"."members" USING "btree" ("org_id");



CREATE INDEX "idx_members_profile" ON "public"."members" USING "btree" ("profile_id");



CREATE INDEX "idx_notifications_staff" ON "public"."staff_notifications" USING "btree" ("staff_id", "is_read");



CREATE INDEX "idx_org_health_scores_org" ON "public"."organization_health_scores" USING "btree" ("org_id");



CREATE INDEX "idx_org_invitations_email" ON "public"."org_invitations" USING "btree" ("email");



CREATE INDEX "idx_org_invitations_org" ON "public"."org_invitations" USING "btree" ("org_id");



CREATE UNIQUE INDEX "idx_org_invitations_pending_unique" ON "public"."org_invitations" USING "btree" ("org_id", "email") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_org_invitations_status" ON "public"."org_invitations" USING "btree" ("status");



CREATE INDEX "idx_org_invitations_token" ON "public"."org_invitations" USING "btree" ("token");



CREATE INDEX "idx_pending_approvals_branch" ON "public"."pending_approvals" USING "btree" ("branch_id");



CREATE INDEX "idx_pending_approvals_member" ON "public"."pending_approvals" USING "btree" ("member_id");



CREATE INDEX "idx_pending_approvals_org" ON "public"."pending_approvals" USING "btree" ("org_id");



CREATE INDEX "idx_pending_approvals_requested_by" ON "public"."pending_approvals" USING "btree" ("requested_by");



CREATE INDEX "idx_pending_approvals_status" ON "public"."pending_approvals" USING "btree" ("status");



CREATE INDEX "idx_platform_activity_feed_created" ON "public"."platform_activity_feed" USING "btree" ("created_at");



CREATE INDEX "idx_platform_announcements_active" ON "public"."platform_announcements" USING "btree" ("is_active");



CREATE INDEX "idx_platform_daily_metrics_date" ON "public"."platform_daily_metrics" USING "btree" ("metric_date");



CREATE INDEX "idx_platform_revenue_org" ON "public"."platform_revenue" USING "btree" ("org_id");



CREATE INDEX "idx_platform_settings_key" ON "public"."platform_settings" USING "btree" ("key");



CREATE INDEX "idx_profiles_branch" ON "public"."profiles" USING "btree" ("branch_id");



CREATE INDEX "idx_profiles_created_at" ON "public"."profiles" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_profiles_org" ON "public"."profiles" USING "btree" ("org_id");



CREATE INDEX "idx_profiles_role" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "idx_savings_collections_collected_at" ON "public"."savings_collections" USING "btree" ("collected_at" DESC);



CREATE INDEX "idx_savings_collections_collected_by_user" ON "public"."savings_collections" USING "btree" ("collected_by_user_id");



CREATE INDEX "idx_savings_collections_entered_by" ON "public"."savings_collections" USING "btree" ("entered_by_user_id");



CREATE INDEX "idx_savings_collections_member" ON "public"."savings_collections" USING "btree" ("member_id");



CREATE INDEX "idx_savings_collections_org" ON "public"."savings_collections" USING "btree" ("org_id");



CREATE INDEX "idx_savings_collections_plan" ON "public"."savings_collections" USING "btree" ("savings_plan_id");



CREATE INDEX "idx_savings_collections_staff" ON "public"."savings_collections" USING "btree" ("staff_id");



CREATE INDEX "idx_savings_collections_transaction_id" ON "public"."savings_collections" USING "btree" ("transaction_id") WHERE ("transaction_id" IS NOT NULL);



CREATE INDEX "idx_savings_created_at" ON "public"."savings" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_savings_member" ON "public"."savings" USING "btree" ("member_id");



CREATE INDEX "idx_savings_org" ON "public"."savings" USING "btree" ("org_id");



CREATE INDEX "idx_savings_plans_created_at" ON "public"."savings_plans" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_savings_plans_member_id" ON "public"."savings_plans" USING "btree" ("member_id");



CREATE INDEX "idx_savings_plans_org" ON "public"."savings_plans" USING "btree" ("org_id");



CREATE INDEX "idx_savings_plans_status" ON "public"."savings_plans" USING "btree" ("status");



CREATE INDEX "idx_savings_status" ON "public"."savings" USING "btree" ("status");



CREATE INDEX "idx_savings_user_id" ON "public"."savings" USING "btree" ("user_id");



CREATE INDEX "idx_sms_notifications_collection" ON "public"."sms_notifications" USING "btree" ("collection_id");



CREATE INDEX "idx_sms_notifications_member" ON "public"."sms_notifications" USING "btree" ("member_id");



CREATE INDEX "idx_sms_notifications_org" ON "public"."sms_notifications" USING "btree" ("org_id");



CREATE INDEX "idx_staff_breaks_staff" ON "public"."staff_breaks" USING "btree" ("staff_id");



CREATE INDEX "idx_staff_locations_branch" ON "public"."staff_locations" USING "btree" ("branch_id");



CREATE INDEX "idx_staff_locations_org_active" ON "public"."staff_locations" USING "btree" ("org_id", "is_active") WHERE ("is_active" = true);



CREATE INDEX "idx_staff_locations_org_recorded" ON "public"."staff_locations" USING "btree" ("org_id", "recorded_at" DESC);



CREATE INDEX "idx_staff_locations_staff" ON "public"."staff_locations" USING "btree" ("staff_id");



CREATE INDEX "idx_staff_locations_staff_recorded" ON "public"."staff_locations" USING "btree" ("staff_id", "recorded_at" DESC);



CREATE INDEX "idx_staff_locations_time" ON "public"."staff_locations" USING "btree" ("recorded_at");



CREATE INDEX "idx_staff_notifications_org" ON "public"."staff_notifications" USING "btree" ("org_id");



CREATE INDEX "idx_staff_profiles_branch" ON "public"."staff_profiles" USING "btree" ("branch_id");



CREATE INDEX "idx_staff_profiles_org" ON "public"."staff_profiles" USING "btree" ("org_id");



CREATE INDEX "idx_staff_profiles_supervisor" ON "public"."staff_profiles" USING "btree" ("supervisor_id");



CREATE INDEX "idx_staff_streaks_org" ON "public"."staff_streaks" USING "btree" ("org_id");



CREATE INDEX "idx_staff_wallet_org" ON "public"."staff_wallet" USING "btree" ("org_id");



CREATE INDEX "idx_support_tickets_assigned" ON "public"."customer_support_tickets" USING "btree" ("assigned_to");



CREATE INDEX "idx_support_tickets_org" ON "public"."customer_support_tickets" USING "btree" ("org_id");



CREATE INDEX "idx_support_tickets_status" ON "public"."support_tickets" USING "btree" ("status");



CREATE INDEX "idx_sync_queue_org" ON "public"."offline_sync_queue" USING "btree" ("org_id");



CREATE INDEX "idx_sync_queue_status" ON "public"."offline_sync_queue" USING "btree" ("status");



CREATE INDEX "idx_system_config_updated_by" ON "public"."system_config" USING "btree" ("updated_by");



CREATE INDEX "idx_system_error_logs_resolved" ON "public"."system_error_logs" USING "btree" ("resolved");



CREATE INDEX "idx_system_settings_org" ON "public"."system_settings" USING "btree" ("org_id");



CREATE INDEX "idx_targets_period" ON "public"."collection_targets" USING "btree" ("period_type", "target_date");



CREATE INDEX "idx_targets_staff" ON "public"."collection_targets" USING "btree" ("staff_id");



CREATE INDEX "idx_ticket_msgs_sender" ON "public"."customer_ticket_messages" USING "btree" ("sender_id");



CREATE INDEX "idx_transactions_collected_at" ON "public"."transactions" USING "btree" ("collected_at" DESC);



CREATE INDEX "idx_transactions_collected_by_user" ON "public"."transactions" USING "btree" ("collected_by_user_id");



CREATE INDEX "idx_transactions_created_at" ON "public"."transactions" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_transactions_entered_by" ON "public"."transactions" USING "btree" ("entered_by_user_id");



CREATE INDEX "idx_transactions_loan_id" ON "public"."transactions" USING "btree" ("loan_id");



CREATE INDEX "idx_transactions_member" ON "public"."transactions" USING "btree" ("member_id");



CREATE INDEX "idx_transactions_org" ON "public"."transactions" USING "btree" ("org_id");



CREATE INDEX "idx_transactions_savings_id" ON "public"."transactions" USING "btree" ("savings_id");



CREATE INDEX "idx_transactions_staff" ON "public"."transactions" USING "btree" ("staff_id");



CREATE INDEX "idx_transactions_type" ON "public"."transactions" USING "btree" ("type");



CREATE INDEX "idx_transactions_user_id" ON "public"."transactions" USING "btree" ("user_id");



CREATE INDEX "idx_visit_logs_customer" ON "public"."visit_logs" USING "btree" ("customer_id");



CREATE INDEX "idx_visit_logs_org" ON "public"."visit_logs" USING "btree" ("org_id");



CREATE INDEX "idx_visits_date" ON "public"."visit_logs" USING "btree" ("check_in_time");



CREATE INDEX "idx_visits_staff" ON "public"."visit_logs" USING "btree" ("staff_id");



CREATE INDEX "idx_wallet_tx_collection" ON "public"."wallet_transactions" USING "btree" ("collection_id");



CREATE INDEX "idx_wallet_tx_org" ON "public"."wallet_transactions" USING "btree" ("org_id");



CREATE INDEX "idx_wallet_tx_staff" ON "public"."wallet_transactions" USING "btree" ("staff_id");



CREATE INDEX "idx_webhook_deliveries_webhook" ON "public"."webhook_deliveries" USING "btree" ("webhook_id");



CREATE INDEX "idx_webhooks_org" ON "public"."webhooks" USING "btree" ("org_id");



CREATE INDEX "savings_plans_installments_paid_idx" ON "public"."savings_plans" USING "btree" ("installments_paid");



CREATE INDEX "upi_payment_requests_customer_idx" ON "public"."upi_payment_requests" USING "btree" ("customer_id", "created_at" DESC);



CREATE INDEX "upi_payment_requests_org_status_idx" ON "public"."upi_payment_requests" USING "btree" ("org_id", "status");



CREATE INDEX "upi_payment_requests_pending_idx" ON "public"."upi_payment_requests" USING "btree" ("org_id", "status", "created_at" DESC) WHERE ("status" = 'pending'::"text");



CREATE OR REPLACE TRIGGER "create_points_on_staff_create" AFTER INSERT ON "public"."staff_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."create_staff_points"();



CREATE OR REPLACE TRIGGER "data_exports_updated_at" BEFORE UPDATE ON "public"."data_exports" FOR EACH ROW EXECUTE FUNCTION "public"."update_data_exports_updated_at"();



CREATE OR REPLACE TRIGGER "on_invitation_created" BEFORE INSERT ON "public"."org_invitations" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_invitation"();



CREATE OR REPLACE TRIGGER "protect_super_admin_delete" BEFORE DELETE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_super_admin_deletion"();



CREATE OR REPLACE TRIGGER "protect_super_admin_role" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_super_admin_role_change"();



CREATE OR REPLACE TRIGGER "trg_admin_notes_updated_at" BEFORE UPDATE ON "public"."admin_notes" FOR EACH ROW EXECUTE FUNCTION "public"."touch_admin_notes_updated_at"();



CREATE OR REPLACE TRIGGER "trg_auto_loan_branch" BEFORE INSERT ON "public"."loans" FOR EACH ROW EXECUTE FUNCTION "public"."auto_set_loan_branch_id"();



CREATE OR REPLACE TRIGGER "trg_ensure_members_profile_link" BEFORE INSERT ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."ensure_members_profile_link"();



CREATE OR REPLACE TRIGGER "trg_fill_collector_collections" BEFORE INSERT ON "public"."collections" FOR EACH ROW EXECUTE FUNCTION "public"."fill_collector_snapshot"();



CREATE OR REPLACE TRIGGER "trg_fill_collector_savings_collections" BEFORE INSERT ON "public"."savings_collections" FOR EACH ROW EXECUTE FUNCTION "public"."fill_collector_snapshot"();



CREATE OR REPLACE TRIGGER "trg_fill_collector_transactions" BEFORE INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."fill_collector_snapshot"();



CREATE OR REPLACE TRIGGER "trg_fix_upi_collection_timestamp" BEFORE INSERT ON "public"."collections" FOR EACH ROW EXECUTE FUNCTION "public"."fix_upi_collection_timestamp"();



CREATE OR REPLACE TRIGGER "trg_fix_upi_transaction_timestamp" BEFORE INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."fix_upi_transaction_timestamp"();



CREATE OR REPLACE TRIGGER "trg_guard_collector_collections" BEFORE UPDATE ON "public"."collections" FOR EACH ROW EXECUTE FUNCTION "public"."guard_collector_snapshot_immutable"();



CREATE OR REPLACE TRIGGER "trg_guard_collector_savings_collections" BEFORE UPDATE ON "public"."savings_collections" FOR EACH ROW EXECUTE FUNCTION "public"."guard_collector_snapshot_immutable"();



CREATE OR REPLACE TRIGGER "trg_guard_collector_transactions" BEFORE UPDATE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."guard_collector_snapshot_immutable"();



CREATE OR REPLACE TRIGGER "trg_link_member_to_profile_on_email" BEFORE UPDATE OF "email" ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."link_member_to_profile_on_email"();



CREATE OR REPLACE TRIGGER "trg_log_member_profile_link_fix" AFTER UPDATE OF "profile_id" ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."log_member_profile_link_fix"();



CREATE OR REPLACE TRIGGER "trg_require_member_profile_id" BEFORE INSERT ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."require_member_profile_id"();



CREATE OR REPLACE TRIGGER "trg_staff_streaks" AFTER INSERT ON "public"."staff_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."create_staff_streaks"();



CREATE OR REPLACE TRIGGER "trg_staff_wallet" AFTER INSERT ON "public"."staff_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."create_staff_wallet"();



CREATE OR REPLACE TRIGGER "trg_sync_collection_is_backdated" AFTER INSERT ON "public"."collection_backdate_audit" FOR EACH ROW EXECUTE FUNCTION "public"."sync_collection_is_backdated"();



CREATE OR REPLACE TRIGGER "trg_sync_member_branch" AFTER UPDATE OF "branch_id" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."sync_member_branch_id"();



CREATE OR REPLACE TRIGGER "trg_sync_member_name" AFTER UPDATE OF "full_name", "phone", "email" ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."sync_member_name_to_profiles"();



CREATE OR REPLACE TRIGGER "trg_sync_profile_name" AFTER UPDATE OF "full_name", "phone", "email" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."sync_profile_name_to_members"();



CREATE OR REPLACE TRIGGER "trg_update_wallet_on_collection" AFTER INSERT ON "public"."collections" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_on_collection"();



CREATE OR REPLACE TRIGGER "update_schedule_on_collection" AFTER INSERT ON "public"."collections" FOR EACH ROW EXECUTE FUNCTION "public"."update_schedule_on_collection_v2"();



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_notes"
    ADD CONSTRAINT "admin_notes_author_profile_id_fkey" FOREIGN KEY ("author_profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."admin_notes"
    ADD CONSTRAINT "admin_notes_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_notes"
    ADD CONSTRAINT "admin_notes_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."agent_areas"
    ADD CONSTRAINT "agent_areas_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."agent_areas"
    ADD CONSTRAINT "agent_areas_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."collection_backdate_audit"
    ADD CONSTRAINT "collection_backdate_audit_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."collection_backdate_audit"
    ADD CONSTRAINT "collection_backdate_audit_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."collection_backdate_audit"
    ADD CONSTRAINT "collection_backdate_audit_performed_by_fkey" FOREIGN KEY ("performed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_collected_by_user_id_fkey" FOREIGN KEY ("collected_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_entered_by_user_id_fkey" FOREIGN KEY ("entered_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_selected_schedule_id_fkey" FOREIGN KEY ("selected_schedule_id") REFERENCES "public"."emi_schedule"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "collections_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."custom_domains"
    ADD CONSTRAINT "custom_domains_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."custom_reports"
    ADD CONSTRAINT "custom_reports_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."custom_reports"
    ADD CONSTRAINT "custom_reports_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."data_exports"
    ADD CONSTRAINT "data_exports_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."data_exports"
    ADD CONSTRAINT "data_exports_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."email_templates"
    ADD CONSTRAINT "email_templates_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "emi_schedule_loan_id_fkey" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "emi_schedule_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."feature_requests"
    ADD CONSTRAINT "feature_requests_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."feature_requests"
    ADD CONSTRAINT "feature_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "fk_activity_logs_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "fk_activity_logs_user" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pending_approvals"
    ADD CONSTRAINT "fk_approvals_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pending_approvals"
    ADD CONSTRAINT "fk_approvals_member" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id");



ALTER TABLE ONLY "public"."pending_approvals"
    ADD CONSTRAINT "fk_approvals_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."pending_approvals"
    ADD CONSTRAINT "fk_approvals_requested" FOREIGN KEY ("requested_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branch_targets"
    ADD CONSTRAINT "fk_branch_targets_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "fk_branches_manager" FOREIGN KEY ("manager_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "fk_branches_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."cash_deposits"
    ADD CONSTRAINT "fk_cash_deposits_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."collection_targets"
    ADD CONSTRAINT "fk_collection_targets_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "fk_collections_loan" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "fk_collections_member" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "fk_collections_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "fk_collections_schedule" FOREIGN KEY ("loan_schedule_id") REFERENCES "public"."emi_schedule"("id");



ALTER TABLE ONLY "public"."collections"
    ADD CONSTRAINT "fk_collections_staff" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customer_notifications"
    ADD CONSTRAINT "fk_cust_notif_customer" FOREIGN KEY ("customer_id") REFERENCES "public"."members"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "fk_emi_loan" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id");



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "fk_emi_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."emi_schedule"
    ADD CONSTRAINT "fk_emi_txn" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions"("id");



ALTER TABLE ONLY "public"."customer_feedback"
    ADD CONSTRAINT "fk_feedback_customer" FOREIGN KEY ("customer_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customer_feedback"
    ADD CONSTRAINT "fk_feedback_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "fk_inv_accepted" FOREIGN KEY ("accepted_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "fk_inv_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "fk_inv_invited" FOREIGN KEY ("invited_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."org_invitations"
    ADD CONSTRAINT "fk_inv_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "fk_loans_agent" FOREIGN KEY ("agent_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "fk_loans_customer" FOREIGN KEY ("customer_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "fk_loans_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "fk_loans_staff" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "fk_members_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "fk_members_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "fk_members_profile" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."savings"
    ADD CONSTRAINT "fk_savings_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."savings"
    ADD CONSTRAINT "fk_savings_user" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "fk_scoll_member" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id");



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "fk_scoll_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "fk_scoll_plan" FOREIGN KEY ("savings_plan_id") REFERENCES "public"."savings_plans"("id");



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "fk_scoll_staff" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."system_settings"
    ADD CONSTRAINT "fk_settings_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."staff_notifications"
    ADD CONSTRAINT "fk_sn_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."staff_profiles"
    ADD CONSTRAINT "fk_sp_branch" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."staff_profiles"
    ADD CONSTRAINT "fk_sp_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."staff_profiles"
    ADD CONSTRAINT "fk_sp_supervisor" FOREIGN KEY ("supervisor_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."savings_plans"
    ADD CONSTRAINT "fk_splans_member" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."savings_plans"
    ADD CONSTRAINT "fk_splans_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."staff_streaks"
    ADD CONSTRAINT "fk_streaks_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."offline_sync_queue"
    ADD CONSTRAINT "fk_sync_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."customer_ticket_messages"
    ADD CONSTRAINT "fk_ticket_msgs_sender" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customer_ticket_messages"
    ADD CONSTRAINT "fk_ticket_msgs_ticket" FOREIGN KEY ("ticket_id") REFERENCES "public"."customer_support_tickets"("id");



ALTER TABLE ONLY "public"."customer_support_tickets"
    ADD CONSTRAINT "fk_tickets_assigned" FOREIGN KEY ("assigned_to") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customer_support_tickets"
    ADD CONSTRAINT "fk_tickets_customer" FOREIGN KEY ("customer_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customer_support_tickets"
    ADD CONSTRAINT "fk_tickets_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "fk_txn_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "fk_txn_savings" FOREIGN KEY ("savings_id") REFERENCES "public"."savings_plans"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "fk_txn_user" FOREIGN KEY ("user_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."visit_logs"
    ADD CONSTRAINT "fk_visit_member" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id");



ALTER TABLE ONLY "public"."visit_logs"
    ADD CONSTRAINT "fk_visit_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."visit_logs"
    ADD CONSTRAINT "fk_visit_staff" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."staff_wallet"
    ADD CONSTRAINT "fk_wallet_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."staff_wallet"
    ADD CONSTRAINT "fk_wallet_staff" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "fk_wtxn_collection" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("id");



ALTER TABLE ONLY "public"."wallet_transactions"
    ADD CONSTRAINT "fk_wtxn_org" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."integrations"
    ADD CONSTRAINT "integrations_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."loan_statements"
    ADD CONSTRAINT "loan_statements_generated_by_fkey" FOREIGN KEY ("generated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."loan_statements"
    ADD CONSTRAINT "loan_statements_loan_id_fkey" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_assigned_collector_id_fkey" FOREIGN KEY ("assigned_collector_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_guarantor_id_fkey" FOREIGN KEY ("guarantor_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."org_branding"
    ADD CONSTRAINT "org_branding_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."org_metrics"
    ADD CONSTRAINT "org_metrics_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."org_settings"
    ADD CONSTRAINT "org_settings_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_payment_method_id_fkey" FOREIGN KEY ("payment_method_id") REFERENCES "public"."payment_methods"("id");



ALTER TABLE ONLY "public"."referrals"
    ADD CONSTRAINT "referrals_referred_org_id_fkey" FOREIGN KEY ("referred_org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."referrals"
    ADD CONSTRAINT "referrals_referrer_org_id_fkey" FOREIGN KEY ("referrer_org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "savings_collections_collected_by_user_id_fkey" FOREIGN KEY ("collected_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "savings_collections_entered_by_user_id_fkey" FOREIGN KEY ("entered_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."savings_collections"
    ADD CONSTRAINT "savings_collections_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sms_notifications"
    ADD CONSTRAINT "sms_notifications_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sms_notifications"
    ADD CONSTRAINT "sms_notifications_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sms_notifications"
    ADD CONSTRAINT "sms_notifications_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sms_notifications"
    ADD CONSTRAINT "sms_notifications_sent_by_fkey" FOREIGN KEY ("sent_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."staff_locations"
    ADD CONSTRAINT "staff_locations_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."staff_locations"
    ADD CONSTRAINT "staff_locations_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."subscription_plans"("id");



ALTER TABLE ONLY "public"."system_config"
    ADD CONSTRAINT "system_config_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_collected_by_user_id_fkey" FOREIGN KEY ("collected_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_entered_by_user_id_fkey" FOREIGN KEY ("entered_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_loan_id_fkey" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_confirmed_by_fkey" FOREIGN KEY ("confirmed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_emi_schedule_id_fkey" FOREIGN KEY ("emi_schedule_id") REFERENCES "public"."emi_schedule"("id");



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_loan_id_fkey" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id");



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id");



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."upi_payment_requests"
    ADD CONSTRAINT "upi_payment_requests_savings_plan_id_fkey" FOREIGN KEY ("savings_plan_id") REFERENCES "public"."savings_plans"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."usage_records"
    ADD CONSTRAINT "usage_records_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."visit_logs"
    ADD CONSTRAINT "visit_logs_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."webhook_deliveries"
    ADD CONSTRAINT "webhook_deliveries_webhook_id_fkey" FOREIGN KEY ("webhook_id") REFERENCES "public"."webhooks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."webhooks"
    ADD CONSTRAINT "webhooks_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



CREATE POLICY "Admins delete admin_notes in org" ON "public"."admin_notes" FOR DELETE USING ((("org_id" = "public"."get_user_org_id"()) AND (("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'superadmin'::"text"])) OR ("author_profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Admins insert admin_notes in org" ON "public"."admin_notes" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'superadmin'::"text", 'executiveAdmin'::"text", 'executiveadmin'::"text", 'admin'::"text"]))));



CREATE POLICY "Admins read admin_notes in org" ON "public"."admin_notes" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'superadmin'::"text", 'executiveAdmin'::"text", 'executiveadmin'::"text", 'admin'::"text"]))));



CREATE POLICY "Admins update admin_notes in org" ON "public"."admin_notes" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND (("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'superadmin'::"text"])) OR ("author_profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Allow admins to update system_config" ON "public"."system_config" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Allow public read for system_config" ON "public"."system_config" FOR SELECT USING (true);



CREATE POLICY "Org members can read SMS logs" ON "public"."sms_notifications" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



CREATE POLICY "Staff can insert SMS logs" ON "public"."sms_notifications" FOR INSERT WITH CHECK (true);



CREATE POLICY "Super admin full access on SMS logs" ON "public"."sms_notifications" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to api_usage_logs" ON "public"."api_usage_logs" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to maintenance_windows" ON "public"."maintenance_windows" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to organization_health_scores" ON "public"."organization_health_scores" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to platform_activity_feed" ON "public"."platform_activity_feed" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to platform_daily_metrics" ON "public"."platform_daily_metrics" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to platform_revenue" ON "public"."platform_revenue" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to platform_settings" ON "public"."platform_settings" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to support_tickets" ON "public"."support_tickets" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Super admin full access to system_error_logs" ON "public"."system_error_logs" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "Users can read org invitations" ON "public"."org_invitations" FOR SELECT TO "authenticated" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."achievements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "achievements_delete" ON "public"."achievements" FOR DELETE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "achievements_insert" ON "public"."achievements" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "achievements_select" ON "public"."achievements" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "achievements_update" ON "public"."achievements" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_logs_insert" ON "public"."activity_logs" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) OR ("staff_id" IN ( SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))) OR ("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())))));



CREATE POLICY "activity_logs_select" ON "public"."activity_logs" FOR SELECT TO "authenticated" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."admin_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."agent_areas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcements_all" ON "public"."announcements" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



CREATE POLICY "announcements_select" ON "public"."announcements" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



ALTER TABLE "public"."api_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."api_usage_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "api_usage_logs_select" ON "public"."api_usage_logs" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



ALTER TABLE "public"."app_updates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_logs_insert" ON "public"."audit_logs" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "audit_logs_select" ON "public"."audit_logs" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text"]))));



ALTER TABLE "public"."branch_targets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branch_targets_insert" ON "public"."branch_targets" FOR INSERT WITH CHECK (true);



CREATE POLICY "branch_targets_select" ON "public"."branch_targets" FOR SELECT USING (true);



CREATE POLICY "branch_targets_update" ON "public"."branch_targets" FOR UPDATE USING (true);



ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branches_delete_admin" ON "public"."branches" FOR DELETE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "branches_insert" ON "public"."branches" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "branches_insert_admin" ON "public"."branches" FOR INSERT WITH CHECK (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "branches_select" ON "public"."branches" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "branches_select_admin" ON "public"."branches" FOR SELECT USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "branches_update_admin" ON "public"."branches" FOR UPDATE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))) WITH CHECK (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."cash_deposits" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cash_deposits_insert" ON "public"."cash_deposits" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "cash_deposits_select" ON "public"."cash_deposits" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "cash_deposits_update" ON "public"."cash_deposits" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."collection_backdate_audit" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "collection_backdate_audit_insert" ON "public"."collection_backdate_audit" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "collection_backdate_audit_select" ON "public"."collection_backdate_audit" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text"]))));



ALTER TABLE "public"."collection_targets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "collection_targets_insert" ON "public"."collection_targets" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "collection_targets_select" ON "public"."collection_targets" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "collection_targets_update" ON "public"."collection_targets" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



ALTER TABLE "public"."collections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."custom_domains" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."custom_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customer_read_own_collections" ON "public"."collections" FOR SELECT USING (("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"()))));



CREATE POLICY "customer_read_own_emi_schedule" ON "public"."emi_schedule" FOR SELECT USING (("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"()))));



CREATE POLICY "customer_read_own_loans" ON "public"."loans" FOR SELECT USING ((("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"()))) OR ("customer_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "customer_read_own_member" ON "public"."members" FOR SELECT USING (("profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "customer_read_own_savings" ON "public"."savings_plans" FOR SELECT USING (("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"()))));



CREATE POLICY "customer_read_own_transactions" ON "public"."transactions" FOR SELECT USING (("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."customer_support_tickets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_ticket_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customers_own_feedback" ON "public"."customer_feedback" USING (("customer_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "customers_own_notifications" ON "public"."customer_notifications" USING (("customer_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "customers_own_ticket_messages" ON "public"."customer_ticket_messages" USING (("ticket_id" IN ( SELECT "customer_support_tickets"."id"
   FROM "public"."customer_support_tickets"
  WHERE ("customer_support_tickets"."customer_id" IN ( SELECT "profiles"."id"
           FROM "public"."profiles"
          WHERE ("profiles"."user_id" = "auth"."uid"()))))));



CREATE POLICY "customers_own_tickets" ON "public"."customer_support_tickets" USING (("customer_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."data_exports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "data_exports_insert" ON "public"."data_exports" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text"]))));



CREATE POLICY "data_exports_select" ON "public"."data_exports" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "data_exports_update" ON "public"."data_exports" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."duty_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "duty_sessions_insert" ON "public"."duty_sessions" FOR INSERT WITH CHECK (("staff_id" = "auth"."uid"()));



CREATE POLICY "duty_sessions_select" ON "public"."duty_sessions" FOR SELECT USING ((("staff_id" = "auth"."uid"()) OR ("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'superAdmin'::"text"])))))));



CREATE POLICY "duty_sessions_update" ON "public"."duty_sessions" FOR UPDATE USING ((("staff_id" = "auth"."uid"()) OR ("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'superAdmin'::"text"])))))));



ALTER TABLE "public"."email_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "email_templates_all" ON "public"."email_templates" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



CREATE POLICY "email_templates_select" ON "public"."email_templates" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



ALTER TABLE "public"."emi_schedule" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "emi_schedule_org_insert" ON "public"."emi_schedule" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("loan_id" IN ( SELECT "loans"."id"
   FROM "public"."loans"
  WHERE ("loans"."org_id" = "public"."get_user_org_id"())))));



CREATE POLICY "emi_schedule_org_select" ON "public"."emi_schedule" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("public"."get_user_role"() = 'superAdmin'::"text") OR ("loan_id" IN ( SELECT "loans"."id"
   FROM "public"."loans"
  WHERE ("loans"."org_id" = "public"."get_user_org_id"())))));



CREATE POLICY "emi_schedule_org_update" ON "public"."emi_schedule" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND ("loan_id" IN ( SELECT "loans"."id"
   FROM "public"."loans"
  WHERE ("loans"."org_id" = "public"."get_user_org_id"())))));



ALTER TABLE "public"."feature_flags" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feature_flags_all" ON "public"."feature_flags" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "feature_flags_select" ON "public"."feature_flags" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



ALTER TABLE "public"."feature_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."help_articles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."integrations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "integrations_all" ON "public"."integrations" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."loan_statements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "loan_statements_delete" ON "public"."loan_statements" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "loan_statements_insert" ON "public"."loan_statements" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "loan_statements_select" ON "public"."loan_statements" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."loans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."maintenance_windows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "members_delete_admin" ON "public"."members" FOR DELETE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "members_insert_admin" ON "public"."members" FOR INSERT WITH CHECK (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "members_update_admin" ON "public"."members" FOR UPDATE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))) WITH CHECK (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."offline_sync_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "offline_sync_queue_delete" ON "public"."offline_sync_queue" FOR DELETE USING ((("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))) OR ("org_id" = "public"."get_user_org_id"())));



CREATE POLICY "offline_sync_queue_insert" ON "public"."offline_sync_queue" FOR INSERT WITH CHECK (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "offline_sync_queue_select" ON "public"."offline_sync_queue" FOR SELECT USING ((("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))) OR ("org_id" = "public"."get_user_org_id"())));



CREATE POLICY "offline_sync_queue_update" ON "public"."offline_sync_queue" FOR UPDATE USING ((("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))) OR ("org_id" = "public"."get_user_org_id"())));



CREATE POLICY "org_admin_custom_domains" ON "public"."custom_domains" USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_admin_subscriptions" ON "public"."subscriptions" USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."org_branding" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "org_branding_insert" ON "public"."org_branding" FOR INSERT WITH CHECK (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



CREATE POLICY "org_branding_select" ON "public"."org_branding" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



CREATE POLICY "org_branding_update" ON "public"."org_branding" FOR UPDATE USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



CREATE POLICY "org_delete" ON "public"."collections" FOR DELETE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'superAdmin'::"text"]))));



CREATE POLICY "org_delete" ON "public"."emi_schedule" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_delete" ON "public"."loans" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_delete" ON "public"."transactions" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_delete_admin" ON "public"."organizations" FOR DELETE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "org_delete_admin" ON "public"."profiles" FOR DELETE USING (("public"."get_user_role"() = 'executiveAdmin'::"text"));



CREATE POLICY "org_insert" ON "public"."loans" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_insert" ON "public"."members" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_insert" ON "public"."organizations" FOR INSERT WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "org_insert" ON "public"."savings" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_insert" ON "public"."staff_profiles" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_insert" ON "public"."transactions" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_insert_admin" ON "public"."profiles" FOR INSERT WITH CHECK (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "org_insert_all" ON "public"."organizations" FOR INSERT WITH CHECK (true);



CREATE POLICY "org_insert_own" ON "public"."profiles" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."org_invitations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "org_invitations_delete" ON "public"."org_invitations" FOR DELETE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text"]))));



CREATE POLICY "org_invitations_insert" ON "public"."org_invitations" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['superAdmin'::"text", 'executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "org_invitations_select" ON "public"."org_invitations" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("email" = "auth"."email"())));



CREATE POLICY "org_invitations_update" ON "public"."org_invitations" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) OR ("email" = "auth"."email"())));



ALTER TABLE "public"."org_metrics" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "org_select" ON "public"."loans" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_select" ON "public"."members" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_select" ON "public"."organizations" FOR SELECT USING ((("id" = "public"."get_user_org_id"()) OR ("created_by" = "auth"."uid"())));



CREATE POLICY "org_select" ON "public"."savings" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_select" ON "public"."staff_profiles" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_select" ON "public"."transactions" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_select_admin" ON "public"."profiles" FOR SELECT USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"])));



CREATE POLICY "org_select_own" ON "public"."profiles" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("user_id" = "auth"."uid"())));



ALTER TABLE "public"."org_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "org_settings_all" ON "public"."org_settings" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



CREATE POLICY "org_settings_select" ON "public"."org_settings" FOR SELECT USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



CREATE POLICY "org_subscriptions_insert" ON "public"."subscriptions" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_subscriptions_select" ON "public"."subscriptions" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_subscriptions_update" ON "public"."subscriptions" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update" ON "public"."loans" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update" ON "public"."members" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update" ON "public"."savings" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update" ON "public"."transactions" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"())) WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update_admin" ON "public"."organizations" FOR UPDATE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))) WITH CHECK (("id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update_admin" ON "public"."profiles" FOR UPDATE USING (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))) WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "org_update_own" ON "public"."profiles" FOR UPDATE USING ((("user_id" = "auth"."uid"()) OR ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"])))) WITH CHECK ((("user_id" = "auth"."uid"()) OR ("org_id" = "public"."get_user_org_id"())));



ALTER TABLE "public"."organization_health_scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_methods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pending_approvals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_activity_feed" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "platform_announcements_all" ON "public"."platform_announcements" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text")))));



CREATE POLICY "platform_announcements_select" ON "public"."platform_announcements" FOR SELECT USING ((("is_active" = true) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'superAdmin'::"text"))))));



ALTER TABLE "public"."platform_daily_metrics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_revenue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platform_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."referrals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."savings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."savings_collections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "savings_collections_delete" ON "public"."savings_collections" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "savings_collections_insert" ON "public"."savings_collections" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "savings_collections_select" ON "public"."savings_collections" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("public"."get_user_role"() = 'superAdmin'::"text")));



CREATE POLICY "savings_collections_update" ON "public"."savings_collections" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."savings_plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "savings_plans_delete" ON "public"."savings_plans" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "savings_plans_insert" ON "public"."savings_plans" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "savings_plans_select" ON "public"."savings_plans" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) OR ("public"."get_user_role"() = 'superAdmin'::"text") OR ("member_id" IN ( SELECT "m"."id"
   FROM ("public"."members" "m"
     JOIN "public"."profiles" "p" ON (("p"."id" = "m"."profile_id")))
  WHERE ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "savings_plans_update" ON "public"."savings_plans" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."sms_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."staff_achievements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_achievements_insert" ON "public"."staff_achievements" FOR INSERT WITH CHECK (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_achievements_select" ON "public"."staff_achievements" FOR SELECT USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_achievements_update" ON "public"."staff_achievements" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."staff_breaks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_breaks_insert" ON "public"."staff_breaks" FOR INSERT WITH CHECK (("staff_id" = "auth"."uid"()));



CREATE POLICY "staff_breaks_select" ON "public"."staff_breaks" FOR SELECT USING ((("staff_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'superAdmin'::"text"])))))));



CREATE POLICY "staff_breaks_update" ON "public"."staff_breaks" FOR UPDATE USING (("staff_id" = "auth"."uid"()));



CREATE POLICY "staff_insert" ON "public"."collections" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'supervisor'::"text", 'collectionAgent'::"text", 'superAdmin'::"text"]))));



ALTER TABLE "public"."staff_locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_locations_insert_v2" ON "public"."staff_locations" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("staff_id" IN ( SELECT "p"."id"
   FROM "public"."profiles" "p"
  WHERE ("p"."user_id" = "auth"."uid"())
UNION ALL
 SELECT "sp"."id"
   FROM "public"."staff_profiles" "sp"
  WHERE ("sp"."user_id" = "auth"."uid"())))));



CREATE POLICY "staff_locations_select_v2" ON "public"."staff_locations" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_locations_update_v2" ON "public"."staff_locations" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."staff_notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_notifications_insert" ON "public"."staff_notifications" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) OR ("staff_id" IN ( SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"())))));



CREATE POLICY "staff_notifications_select" ON "public"."staff_notifications" FOR SELECT USING ((("staff_id" IN ( SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))) OR ("org_id" = "public"."get_user_org_id"())));



CREATE POLICY "staff_notifications_update" ON "public"."staff_notifications" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."staff_points" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_points_insert" ON "public"."staff_points" FOR INSERT WITH CHECK (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."staff_points_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_points_log_insert" ON "public"."staff_points_log" FOR INSERT WITH CHECK (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_points_log_select" ON "public"."staff_points_log" FOR SELECT USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_points_select" ON "public"."staff_points" FOR SELECT USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_points_update" ON "public"."staff_points" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."staff_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_profiles_org_delete" ON "public"."staff_profiles" FOR DELETE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_profiles_org_update" ON "public"."staff_profiles" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_see_branch_pending_approvals" ON "public"."pending_approvals" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_select" ON "public"."collections" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) AND (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'supervisor'::"text"])) OR ("public"."get_user_role"() = 'superAdmin'::"text") OR ("staff_id" IN ( SELECT "p"."id"
   FROM "public"."profiles" "p"
  WHERE ("p"."user_id" = "auth"."uid"())
UNION
 SELECT "sp"."id"
   FROM "public"."staff_profiles" "sp"
  WHERE ("sp"."user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."staff_streaks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_streaks_insert" ON "public"."staff_streaks" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"())))));



CREATE POLICY "staff_streaks_select" ON "public"."staff_streaks" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_streaks_update" ON "public"."staff_streaks" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "staff_update" ON "public"."collections" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND (("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'supervisor'::"text"])) OR ("public"."get_user_role"() = 'superAdmin'::"text") OR ("staff_id" IN ( SELECT "p"."id"
   FROM "public"."profiles" "p"
  WHERE ("p"."user_id" = "auth"."uid"())
UNION
 SELECT "sp"."id"
   FROM "public"."staff_profiles" "sp"
  WHERE ("sp"."user_id" = "auth"."uid"())))))) WITH CHECK (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."staff_wallet" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_wallet_insert" ON "public"."staff_wallet" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_wallet_select" ON "public"."staff_wallet" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "staff_wallet_update" ON "public"."staff_wallet" FOR UPDATE USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."subscription_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "super_admin_subscriptions" ON "public"."subscriptions" USING ("public"."is_super_admin"());



ALTER TABLE "public"."support_tickets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sync_conflicts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sync_conflicts_insert" ON "public"."sync_conflicts" FOR INSERT WITH CHECK (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "sync_conflicts_select" ON "public"."sync_conflicts" FOR SELECT USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "sync_conflicts_update" ON "public"."sync_conflicts" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."system_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."system_error_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."system_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "system_settings_delete" ON "public"."system_settings" FOR DELETE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "system_settings_insert" ON "public"."system_settings" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



CREATE POLICY "system_settings_select" ON "public"."system_settings" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "system_settings_update" ON "public"."system_settings" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text"]))));



ALTER TABLE "public"."system_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."upi_payment_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "upi_req_insert_own" ON "public"."upi_payment_requests" FOR INSERT WITH CHECK (("customer_id" = "auth"."uid"()));



CREATE POLICY "upi_req_select_org" ON "public"."upi_payment_requests" FOR SELECT USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text"]))));



CREATE POLICY "upi_req_select_own" ON "public"."upi_payment_requests" FOR SELECT USING (("customer_id" = "auth"."uid"()));



CREATE POLICY "upi_req_update_org" ON "public"."upi_payment_requests" FOR UPDATE USING ((("org_id" = "public"."get_user_org_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['executiveAdmin'::"text", 'manager'::"text", 'collectionAgent'::"text"]))));



ALTER TABLE "public"."usage_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."video_tutorials" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."visit_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visit_logs_insert" ON "public"."visit_logs" FOR INSERT WITH CHECK ((("org_id" = "public"."get_user_org_id"()) AND ("staff_id" IN ( SELECT "p"."id"
   FROM "public"."profiles" "p"
  WHERE ("p"."user_id" = "auth"."uid"())
UNION ALL
 SELECT "sp"."id"
   FROM "public"."staff_profiles" "sp"
  WHERE ("sp"."user_id" = "auth"."uid"())))));



CREATE POLICY "visit_logs_select" ON "public"."visit_logs" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "visit_logs_update" ON "public"."visit_logs" FOR UPDATE USING (("staff_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())
UNION
 SELECT "staff_profiles"."id"
   FROM "public"."staff_profiles"
  WHERE ("staff_profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."wallet_transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "wallet_transactions_insert" ON "public"."wallet_transactions" FOR INSERT WITH CHECK (("org_id" = "public"."get_user_org_id"()));



CREATE POLICY "wallet_transactions_select" ON "public"."wallet_transactions" FOR SELECT USING (("org_id" = "public"."get_user_org_id"()));



ALTER TABLE "public"."webhook_deliveries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "webhook_deliveries_select" ON "public"."webhook_deliveries" FOR SELECT USING (("webhook_id" IN ( SELECT "webhooks"."id"
   FROM "public"."webhooks"
  WHERE ("webhooks"."org_id" IN ( SELECT "profiles"."org_id"
           FROM "public"."profiles"
          WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))))));



ALTER TABLE "public"."webhooks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "webhooks_all" ON "public"."webhooks" USING (("org_id" IN ( SELECT "profiles"."org_id"
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['executiveAdmin'::"text", 'superAdmin'::"text"]))))));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."accept_invitation"("p_token" "text", "p_full_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_invitation"("p_token" "text", "p_full_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_invitation"("p_token" "text", "p_full_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_set_loan_branch_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_set_loan_branch_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_set_loan_branch_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_email_exists"("p_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_email_exists"("p_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_email_exists"("p_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_setup_complete"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_setup_complete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_setup_complete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_subscription_limit"("p_org_id" "uuid", "p_limit_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_subscription_limit"("p_org_id" "uuid", "p_limit_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_subscription_limit"("p_org_id" "uuid", "p_limit_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_invitations"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_invitations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_invitations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_locations"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_locations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_locations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_invitation"("p_org_id" "uuid", "p_email" "text", "p_role" "text", "p_branch_id" "uuid", "p_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_invitation"("p_org_id" "uuid", "p_email" "text", "p_role" "text", "p_branch_id" "uuid", "p_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_invitation"("p_org_id" "uuid", "p_email" "text", "p_role" "text", "p_branch_id" "uuid", "p_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_staff_points"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_staff_points"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_staff_points"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_staff_streaks"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_staff_streaks"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_staff_streaks"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_staff_wallet"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_staff_wallet"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_staff_wallet"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_loan_collection"("p_collection_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_loan_collection"("p_collection_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_loan_collection"("p_collection_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_loan_safely"("p_loan_id" "uuid", "p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_loan_safely"("p_loan_id" "uuid", "p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_loan_safely"("p_loan_id" "uuid", "p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_savings_safely"("p_savings_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_savings_safely"("p_savings_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_savings_safely"("p_savings_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_savings_transaction"("p_transaction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_savings_transaction"("p_transaction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_savings_transaction"("p_transaction_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_transaction_with_revert"("p_transaction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_transaction_with_revert"("p_transaction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_transaction_with_revert"("p_transaction_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_members_profile_link"() TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_members_profile_link"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_members_profile_link"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fill_collector_snapshot"() TO "anon";
GRANT ALL ON FUNCTION "public"."fill_collector_snapshot"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fill_collector_snapshot"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_upi_collection_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."fix_upi_collection_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_upi_collection_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_upi_transaction_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."fix_upi_transaction_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_upi_transaction_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_emi_schedule"("p_loan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_emi_schedule"("p_loan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_emi_schedule"("p_loan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_verification_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_verification_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_verification_token"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_daily_summary"("p_branch_id" "uuid", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_daily_summary"("p_branch_id" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_daily_summary"("p_branch_id" "uuid", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_staff_performance"("p_branch_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_staff_performance"("p_branch_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_staff_performance"("p_branch_id" "uuid", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_stats"("p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_stats"("p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_stats"("p_branch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_frequent_customers"("p_staff_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_frequent_customers"("p_staff_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_frequent_customers"("p_staff_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_latest_staff_locations"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_latest_staff_locations"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_latest_staff_locations"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_member_id_for_auth"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_member_id_for_auth"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_member_id_for_auth"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_platform_metrics"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_platform_metrics"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_platform_metrics"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_staff_rank"("p_staff_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_staff_rank"("p_staff_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_staff_rank"("p_staff_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subscription_status"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subscription_status"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subscription_status"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_org_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_org_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_org_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_collector_snapshot_immutable"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_collector_snapshot_immutable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_collector_snapshot_immutable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user_creates_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user_creates_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user_creates_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_invitation"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_invitation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_invitation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user_welcome"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user_welcome"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user_welcome"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."link_member_to_profile_on_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."link_member_to_profile_on_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_member_to_profile_on_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_audit_event"("p_org_id" "uuid", "p_user_id" "uuid", "p_action" "text", "p_entity_type" "text", "p_entity_id" "text", "p_description" "text", "p_old_values" "jsonb", "p_new_values" "jsonb", "p_severity" "text", "p_category" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."log_audit_event"("p_org_id" "uuid", "p_user_id" "uuid", "p_action" "text", "p_entity_type" "text", "p_entity_id" "text", "p_description" "text", "p_old_values" "jsonb", "p_new_values" "jsonb", "p_severity" "text", "p_category" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_audit_event"("p_org_id" "uuid", "p_user_id" "uuid", "p_action" "text", "p_entity_type" "text", "p_entity_id" "text", "p_description" "text", "p_old_values" "jsonb", "p_new_values" "jsonb", "p_severity" "text", "p_category" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_member_profile_link_fix"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_member_profile_link_fix"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_member_profile_link_fix"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_super_admin_auth_deletion"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_auth_deletion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_auth_deletion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_super_admin_deletion"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_deletion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_deletion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_super_admin_role_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_role_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_super_admin_role_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rebuild_emi_schedule_from_collections"("p_loan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rebuild_emi_schedule_from_collections"("p_loan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rebuild_emi_schedule_from_collections"("p_loan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_loan_outstanding"("p_loan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_loan_outstanding"("p_loan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_loan_outstanding"("p_loan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_savings_balance"("p_savings_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_savings_balance"("p_savings_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_savings_balance"("p_savings_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."require_member_profile_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."require_member_profile_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."require_member_profile_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."resend_invitation"("p_invitation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resend_invitation"("p_invitation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resend_invitation"("p_invitation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."revoke_invitation"("p_invitation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."revoke_invitation"("p_invitation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."revoke_invitation"("p_invitation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_collection_is_backdated"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_collection_is_backdated"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_collection_is_backdated"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_member_branch_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_member_branch_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_member_branch_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_member_name_to_profiles"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_member_name_to_profiles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_member_name_to_profiles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_profile_name_to_members"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_profile_name_to_members"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_profile_name_to_members"() TO "service_role";



GRANT ALL ON FUNCTION "public"."test_func_simple"() TO "anon";
GRANT ALL ON FUNCTION "public"."test_func_simple"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_func_simple"() TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_admin_notes_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_admin_notes_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_admin_notes_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_data_exports_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_data_exports_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_data_exports_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_schedule_on_collection"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_schedule_on_collection"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_schedule_on_collection"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_schedule_on_collection_v2"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_schedule_on_collection_v2"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_schedule_on_collection_v2"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_staff_points"("p_staff_id" "uuid", "p_points" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_staff_points"("p_staff_id" "uuid", "p_points" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_staff_points"("p_staff_id" "uuid", "p_points" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallet_on_collection"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallet_on_collection"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallet_on_collection"() TO "service_role";



GRANT ALL ON TABLE "public"."achievements" TO "anon";
GRANT ALL ON TABLE "public"."achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."achievements" TO "service_role";



GRANT ALL ON TABLE "public"."activity_logs" TO "anon";
GRANT ALL ON TABLE "public"."activity_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_logs" TO "service_role";



GRANT ALL ON TABLE "public"."admin_notes" TO "anon";
GRANT ALL ON TABLE "public"."admin_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_notes" TO "service_role";



GRANT ALL ON TABLE "public"."agent_areas" TO "anon";
GRANT ALL ON TABLE "public"."agent_areas" TO "authenticated";
GRANT ALL ON TABLE "public"."agent_areas" TO "service_role";



GRANT ALL ON TABLE "public"."announcements" TO "anon";
GRANT ALL ON TABLE "public"."announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."announcements" TO "service_role";



GRANT ALL ON TABLE "public"."api_keys" TO "anon";
GRANT ALL ON TABLE "public"."api_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."api_keys" TO "service_role";



GRANT ALL ON TABLE "public"."api_usage_logs" TO "anon";
GRANT ALL ON TABLE "public"."api_usage_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."api_usage_logs" TO "service_role";



GRANT ALL ON TABLE "public"."app_updates" TO "anon";
GRANT ALL ON TABLE "public"."app_updates" TO "authenticated";
GRANT ALL ON TABLE "public"."app_updates" TO "service_role";



GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."branch_targets" TO "anon";
GRANT ALL ON TABLE "public"."branch_targets" TO "authenticated";
GRANT ALL ON TABLE "public"."branch_targets" TO "service_role";



GRANT ALL ON TABLE "public"."branches" TO "anon";
GRANT ALL ON TABLE "public"."branches" TO "authenticated";
GRANT ALL ON TABLE "public"."branches" TO "service_role";



GRANT ALL ON TABLE "public"."cash_deposits" TO "anon";
GRANT ALL ON TABLE "public"."cash_deposits" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_deposits" TO "service_role";



GRANT ALL ON TABLE "public"."collection_backdate_audit" TO "anon";
GRANT ALL ON TABLE "public"."collection_backdate_audit" TO "authenticated";
GRANT ALL ON TABLE "public"."collection_backdate_audit" TO "service_role";



GRANT ALL ON TABLE "public"."collection_targets" TO "anon";
GRANT ALL ON TABLE "public"."collection_targets" TO "authenticated";
GRANT ALL ON TABLE "public"."collection_targets" TO "service_role";



GRANT ALL ON TABLE "public"."collections" TO "anon";
GRANT ALL ON TABLE "public"."collections" TO "authenticated";
GRANT ALL ON TABLE "public"."collections" TO "service_role";



GRANT ALL ON TABLE "public"."custom_domains" TO "anon";
GRANT ALL ON TABLE "public"."custom_domains" TO "authenticated";
GRANT ALL ON TABLE "public"."custom_domains" TO "service_role";



GRANT ALL ON TABLE "public"."custom_reports" TO "anon";
GRANT ALL ON TABLE "public"."custom_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."custom_reports" TO "service_role";



GRANT ALL ON TABLE "public"."customer_feedback" TO "anon";
GRANT ALL ON TABLE "public"."customer_feedback" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_feedback" TO "service_role";



GRANT ALL ON TABLE "public"."customer_notifications" TO "anon";
GRANT ALL ON TABLE "public"."customer_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."customer_support_tickets" TO "anon";
GRANT ALL ON TABLE "public"."customer_support_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_support_tickets" TO "service_role";



GRANT ALL ON TABLE "public"."customer_ticket_messages" TO "anon";
GRANT ALL ON TABLE "public"."customer_ticket_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_ticket_messages" TO "service_role";



GRANT ALL ON TABLE "public"."data_exports" TO "anon";
GRANT ALL ON TABLE "public"."data_exports" TO "authenticated";
GRANT ALL ON TABLE "public"."data_exports" TO "service_role";



GRANT ALL ON TABLE "public"."duty_sessions" TO "anon";
GRANT ALL ON TABLE "public"."duty_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."duty_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."email_templates" TO "anon";
GRANT ALL ON TABLE "public"."email_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."email_templates" TO "service_role";



GRANT ALL ON TABLE "public"."emi_schedule" TO "anon";
GRANT ALL ON TABLE "public"."emi_schedule" TO "authenticated";
GRANT ALL ON TABLE "public"."emi_schedule" TO "service_role";



GRANT ALL ON TABLE "public"."feature_flags" TO "anon";
GRANT ALL ON TABLE "public"."feature_flags" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_flags" TO "service_role";



GRANT ALL ON TABLE "public"."feature_requests" TO "anon";
GRANT ALL ON TABLE "public"."feature_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_requests" TO "service_role";



GRANT ALL ON TABLE "public"."help_articles" TO "anon";
GRANT ALL ON TABLE "public"."help_articles" TO "authenticated";
GRANT ALL ON TABLE "public"."help_articles" TO "service_role";



GRANT ALL ON TABLE "public"."integrations" TO "anon";
GRANT ALL ON TABLE "public"."integrations" TO "authenticated";
GRANT ALL ON TABLE "public"."integrations" TO "service_role";



GRANT ALL ON TABLE "public"."invoices" TO "anon";
GRANT ALL ON TABLE "public"."invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."invoices" TO "service_role";



GRANT ALL ON TABLE "public"."loan_schedules" TO "anon";
GRANT ALL ON TABLE "public"."loan_schedules" TO "authenticated";
GRANT ALL ON TABLE "public"."loan_schedules" TO "service_role";



GRANT ALL ON TABLE "public"."loan_statements" TO "anon";
GRANT ALL ON TABLE "public"."loan_statements" TO "authenticated";
GRANT ALL ON TABLE "public"."loan_statements" TO "service_role";



GRANT ALL ON TABLE "public"."loans" TO "anon";
GRANT ALL ON TABLE "public"."loans" TO "authenticated";
GRANT ALL ON TABLE "public"."loans" TO "service_role";



GRANT ALL ON TABLE "public"."maintenance_windows" TO "anon";
GRANT ALL ON TABLE "public"."maintenance_windows" TO "authenticated";
GRANT ALL ON TABLE "public"."maintenance_windows" TO "service_role";



GRANT ALL ON TABLE "public"."members" TO "anon";
GRANT ALL ON TABLE "public"."members" TO "authenticated";
GRANT ALL ON TABLE "public"."members" TO "service_role";



GRANT ALL ON TABLE "public"."offline_sync_queue" TO "anon";
GRANT ALL ON TABLE "public"."offline_sync_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."offline_sync_queue" TO "service_role";



GRANT ALL ON TABLE "public"."org_branding" TO "anon";
GRANT ALL ON TABLE "public"."org_branding" TO "authenticated";
GRANT ALL ON TABLE "public"."org_branding" TO "service_role";



GRANT ALL ON TABLE "public"."org_invitations" TO "anon";
GRANT ALL ON TABLE "public"."org_invitations" TO "authenticated";
GRANT ALL ON TABLE "public"."org_invitations" TO "service_role";



GRANT ALL ON TABLE "public"."org_metrics" TO "anon";
GRANT ALL ON TABLE "public"."org_metrics" TO "authenticated";
GRANT ALL ON TABLE "public"."org_metrics" TO "service_role";



GRANT ALL ON TABLE "public"."org_settings" TO "anon";
GRANT ALL ON TABLE "public"."org_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."org_settings" TO "service_role";



GRANT ALL ON TABLE "public"."organization_health_scores" TO "anon";
GRANT ALL ON TABLE "public"."organization_health_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."organization_health_scores" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."overdue_loans_view" TO "anon";
GRANT ALL ON TABLE "public"."overdue_loans_view" TO "authenticated";
GRANT ALL ON TABLE "public"."overdue_loans_view" TO "service_role";



GRANT ALL ON TABLE "public"."payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_methods" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."pending_approvals" TO "anon";
GRANT ALL ON TABLE "public"."pending_approvals" TO "authenticated";
GRANT ALL ON TABLE "public"."pending_approvals" TO "service_role";



GRANT ALL ON TABLE "public"."platform_activity_feed" TO "anon";
GRANT ALL ON TABLE "public"."platform_activity_feed" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_activity_feed" TO "service_role";



GRANT ALL ON TABLE "public"."platform_announcements" TO "anon";
GRANT ALL ON TABLE "public"."platform_announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_announcements" TO "service_role";



GRANT ALL ON TABLE "public"."platform_daily_metrics" TO "anon";
GRANT ALL ON TABLE "public"."platform_daily_metrics" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_daily_metrics" TO "service_role";



GRANT ALL ON TABLE "public"."platform_revenue" TO "anon";
GRANT ALL ON TABLE "public"."platform_revenue" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_revenue" TO "service_role";



GRANT ALL ON TABLE "public"."platform_settings" TO "anon";
GRANT ALL ON TABLE "public"."platform_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."platform_settings" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."referrals" TO "anon";
GRANT ALL ON TABLE "public"."referrals" TO "authenticated";
GRANT ALL ON TABLE "public"."referrals" TO "service_role";



GRANT ALL ON TABLE "public"."savings" TO "anon";
GRANT ALL ON TABLE "public"."savings" TO "authenticated";
GRANT ALL ON TABLE "public"."savings" TO "service_role";



GRANT ALL ON TABLE "public"."savings_collections" TO "anon";
GRANT ALL ON TABLE "public"."savings_collections" TO "authenticated";
GRANT ALL ON TABLE "public"."savings_collections" TO "service_role";



GRANT ALL ON TABLE "public"."savings_deposits" TO "anon";
GRANT ALL ON TABLE "public"."savings_deposits" TO "authenticated";
GRANT ALL ON TABLE "public"."savings_deposits" TO "service_role";



GRANT ALL ON TABLE "public"."savings_plans" TO "anon";
GRANT ALL ON TABLE "public"."savings_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."savings_plans" TO "service_role";



GRANT ALL ON TABLE "public"."sms_notifications" TO "anon";
GRANT ALL ON TABLE "public"."sms_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."sms_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."staff_achievements" TO "anon";
GRANT ALL ON TABLE "public"."staff_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_achievements" TO "service_role";



GRANT ALL ON TABLE "public"."staff_breaks" TO "anon";
GRANT ALL ON TABLE "public"."staff_breaks" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_breaks" TO "service_role";



GRANT ALL ON TABLE "public"."staff_points" TO "anon";
GRANT ALL ON TABLE "public"."staff_points" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_points" TO "service_role";



GRANT ALL ON TABLE "public"."staff_profiles" TO "anon";
GRANT ALL ON TABLE "public"."staff_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."staff_streaks" TO "anon";
GRANT ALL ON TABLE "public"."staff_streaks" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_streaks" TO "service_role";



GRANT ALL ON TABLE "public"."staff_leaderboard_view" TO "anon";
GRANT ALL ON TABLE "public"."staff_leaderboard_view" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_leaderboard_view" TO "service_role";



GRANT ALL ON TABLE "public"."staff_locations" TO "anon";
GRANT ALL ON TABLE "public"."staff_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_locations" TO "service_role";



GRANT ALL ON TABLE "public"."staff_notifications" TO "anon";
GRANT ALL ON TABLE "public"."staff_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."staff_points_log" TO "anon";
GRANT ALL ON TABLE "public"."staff_points_log" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_points_log" TO "service_role";



GRANT ALL ON TABLE "public"."staff_today_summary" TO "anon";
GRANT ALL ON TABLE "public"."staff_today_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_today_summary" TO "service_role";



GRANT ALL ON TABLE "public"."staff_wallet" TO "anon";
GRANT ALL ON TABLE "public"."staff_wallet" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_wallet" TO "service_role";



GRANT ALL ON TABLE "public"."subscription_plans" TO "anon";
GRANT ALL ON TABLE "public"."subscription_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_plans" TO "service_role";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."support_tickets" TO "anon";
GRANT ALL ON TABLE "public"."support_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."support_tickets" TO "service_role";



GRANT ALL ON TABLE "public"."sync_conflicts" TO "anon";
GRANT ALL ON TABLE "public"."sync_conflicts" TO "authenticated";
GRANT ALL ON TABLE "public"."sync_conflicts" TO "service_role";



GRANT ALL ON TABLE "public"."system_config" TO "anon";
GRANT ALL ON TABLE "public"."system_config" TO "authenticated";
GRANT ALL ON TABLE "public"."system_config" TO "service_role";



GRANT ALL ON TABLE "public"."system_error_logs" TO "anon";
GRANT ALL ON TABLE "public"."system_error_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."system_error_logs" TO "service_role";



GRANT ALL ON TABLE "public"."system_settings" TO "anon";
GRANT ALL ON TABLE "public"."system_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."system_settings" TO "service_role";



GRANT ALL ON TABLE "public"."system_status" TO "anon";
GRANT ALL ON TABLE "public"."system_status" TO "authenticated";
GRANT ALL ON TABLE "public"."system_status" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."upi_payment_requests" TO "anon";
GRANT ALL ON TABLE "public"."upi_payment_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."upi_payment_requests" TO "service_role";



GRANT ALL ON TABLE "public"."usage_records" TO "anon";
GRANT ALL ON TABLE "public"."usage_records" TO "authenticated";
GRANT ALL ON TABLE "public"."usage_records" TO "service_role";



GRANT ALL ON TABLE "public"."video_tutorials" TO "anon";
GRANT ALL ON TABLE "public"."video_tutorials" TO "authenticated";
GRANT ALL ON TABLE "public"."video_tutorials" TO "service_role";



GRANT ALL ON TABLE "public"."visit_logs" TO "anon";
GRANT ALL ON TABLE "public"."visit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."visit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_transactions" TO "anon";
GRANT ALL ON TABLE "public"."wallet_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."webhook_deliveries" TO "anon";
GRANT ALL ON TABLE "public"."webhook_deliveries" TO "authenticated";
GRANT ALL ON TABLE "public"."webhook_deliveries" TO "service_role";



GRANT ALL ON TABLE "public"."webhooks" TO "anon";
GRANT ALL ON TABLE "public"."webhooks" TO "authenticated";
GRANT ALL ON TABLE "public"."webhooks" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







