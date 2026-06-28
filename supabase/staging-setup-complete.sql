-- ============================================
-- MicroFlow Pro - Complete Staging Setup
-- ============================================
-- This script sets up the staging environment
-- as the development/testing server
-- ============================================

-- IMPORTANT: Run this in the Supabase SQL Editor
-- Dashboard: https://supabase.com/dashboard/project/mirdnsifontxoccjwgak/sql/new

-- ============================================
-- STEP 1: Clean up existing test data
-- ============================================
DO $$
BEGIN
    -- Clean up broken auth identities and users
    DELETE FROM auth.identities WHERE user_id IN (
        SELECT id FROM auth.users WHERE email IN (
            'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
            'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
        )
    );
    DELETE FROM auth.sessions WHERE user_id IN (
        SELECT id FROM auth.users WHERE email IN (
            'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
            'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
        )
    );
    DELETE FROM auth.users WHERE email IN (
        'testadmin@microflow.com', 'manager@gmail.com', 'collection@gmail.com', 'customer@gmail.com',
        'freshuser@microflow.com', 'test_verify@microflow.com', 'newtest@microflow.com'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Cleanup completed (some tables may not exist yet)';
END $$;

-- ============================================
-- STEP 2: Create Test Organization
-- ============================================
DO $$
DECLARE
    v_org_id UUID := 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9';
    v_branch_id UUID := '769d81ce-3530-4ca3-83e8-76742496d45b';
BEGIN
    -- Delete existing test data if any
    DELETE FROM public.profiles WHERE org_id = v_org_id;
    DELETE FROM public.branches WHERE org_id = v_org_id;
    DELETE FROM public.organizations WHERE id = v_org_id;

    -- Create test organization
    INSERT INTO public.organizations (id, name, slug, status, created_at)
    VALUES (v_org_id, 'Test Org', 'test-org', 'active', now());

    -- Create test branch
    INSERT INTO public.branches (id, org_id, name, code, status, created_at)
    VALUES (v_branch_id, v_org_id, 'Test Branch', 'TB001', 'active', now());

    RAISE NOTICE 'Test organization and branch created successfully';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error creating organization: %', SQLERRM;
END $$;

-- ============================================
-- STEP 3: Create Test Users with Profiles
-- ============================================
-- Password for all test users: password123
-- ============================================
DO $$
DECLARE
    v_org_id UUID := 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9';
    v_branch_id UUID := '769d81ce-3530-4ca3-83e8-76742496d45b';
    v_user_id UUID;
    v_password_hash TEXT;
BEGIN
    -- Generate proper bcrypt hash for 'password123'
    SELECT crypt('password123', gen_salt('bf', 10)) INTO v_password_hash;
    -- User 1: Executive Admin
    v_user_id := 'a1111111-1111-1111-1111-111111111111';
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user_id, 'authenticated', 'authenticated', 'testadmin@microflow.com', v_password_hash, now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Admin"}', now(), now());
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
    VALUES (gen_random_uuid(), v_user_id, '{"sub":"'||v_user_id||'","email":"testadmin@microflow.com","email_verified":true}', 'email', 'testadmin@microflow.com', now(), now());
    INSERT INTO public.profiles (user_id, email, full_name, role, org_id, branch_id, status, is_active)
    VALUES (v_user_id, 'testadmin@microflow.com', 'Test Admin', 'executiveAdmin', v_org_id, null, 'active', true);
    RAISE NOTICE 'Created Executive Admin: testadmin@microflow.com';

    -- User 2: Branch Manager
    v_user_id := 'b2222222-2222-2222-2222-222222222222';
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user_id, 'authenticated', 'authenticated', 'manager@gmail.com', v_password_hash, now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Branch Manager"}', now(), now());
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
    VALUES (gen_random_uuid(), v_user_id, '{"sub":"'||v_user_id||'","email":"manager@gmail.com","email_verified":true}', 'email', 'manager@gmail.com', now(), now());
    INSERT INTO public.profiles (user_id, email, full_name, role, org_id, branch_id, status, is_active)
    VALUES (v_user_id, 'manager@gmail.com', 'Branch Manager', 'manager', v_org_id, v_branch_id, 'active', true);
    RAISE NOTICE 'Created Branch Manager: manager@gmail.com';

    -- User 3: Collection Agent
    v_user_id := 'c3333333-3333-3333-3333-333333333333';
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user_id, 'authenticated', 'authenticated', 'collection@gmail.com', v_password_hash, now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Collection Agent"}', now(), now());
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
    VALUES (gen_random_uuid(), v_user_id, '{"sub":"'||v_user_id||'","email":"collection@gmail.com","email_verified":true}', 'email', 'collection@gmail.com', now(), now());
    INSERT INTO public.profiles (user_id, email, full_name, role, org_id, branch_id, status, is_active)
    VALUES (v_user_id, 'collection@gmail.com', 'Collection Agent', 'collectionAgent', v_org_id, v_branch_id, 'active', true);
    RAISE NOTICE 'Created Collection Agent: collection@gmail.com';

    -- User 4: Customer
    v_user_id := 'd4444444-4444-4444-4444-444444444444';
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user_id, 'authenticated', 'authenticated', 'customer@gmail.com', v_password_hash, now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Customer"}', now(), now());
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
    VALUES (gen_random_uuid(), v_user_id, '{"sub":"'||v_user_id||'","email":"customer@gmail.com","email_verified":true}', 'email', 'customer@gmail.com', now(), now());
    INSERT INTO public.profiles (user_id, email, full_name, role, org_id, branch_id, status, is_active)
    VALUES (v_user_id, 'customer@gmail.com', 'Test Customer', 'customer', v_org_id, v_branch_id, 'active', true);
    RAISE NOTICE 'Created Customer: customer@gmail.com';

    RAISE NOTICE 'All test users created successfully!';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error creating test users: %', SQLERRM;
END $$;

-- ============================================
-- STEP 4: Create Staff Wallets for Test Users
-- ============================================
DO $$
BEGIN
    -- Create wallets for staff users
    INSERT INTO public.staff_wallet (staff_id, org_id, cash_in_hand, total_collected_today, last_updated)
    SELECT user_id, org_id, 0, 0, now()
    FROM public.profiles
    WHERE role IN ('executiveAdmin', 'manager', 'collectionAgent')
    AND org_id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'
    ON CONFLICT (staff_id) DO NOTHING;

    RAISE NOTICE 'Staff wallets created/updated';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Staff wallet creation skipped (table may not exist yet)';
END $$;

-- ============================================
-- STEP 5: Create Staff Streaks for Test Users
-- ============================================
DO $$
BEGIN
    -- Create streaks for staff users
    INSERT INTO public.staff_streaks (staff_id, current_streak, longest_streak, last_collection_date)
    SELECT user_id, 0, 0, NULL
    FROM public.profiles
    WHERE role IN ('executiveAdmin', 'manager', 'collectionAgent')
    AND org_id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'
    ON CONFLICT (staff_id) DO NOTHING;

    RAISE NOTICE 'Staff streaks created/updated';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Staff streak creation skipped (table may not exist yet)';
END $$;

-- ============================================
-- STEP 6: Create Staff Points for Test Users
-- ============================================
DO $$
BEGIN
    -- Create points for staff users
    INSERT INTO public.staff_points (staff_id, org_id, total_points)
    SELECT user_id, org_id, 0
    FROM public.profiles
    WHERE role IN ('executiveAdmin', 'manager', 'collectionAgent')
    AND org_id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'
    ON CONFLICT (staff_id) DO NOTHING;

    RAISE NOTICE 'Staff points created/updated';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Staff points creation skipped (table may not exist yet)';
END $$;

-- ============================================
-- STEP 7: Verify Setup
-- ============================================
DO $$
BEGIN
    -- Verify organization exists
    IF EXISTS (SELECT 1 FROM public.organizations WHERE id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9') THEN
        RAISE NOTICE '✓ Test organization exists';
    ELSE
        RAISE NOTICE '✗ Test organization missing';
    END IF;

    -- Verify branch exists
    IF EXISTS (SELECT 1 FROM public.branches WHERE id = '769d81ce-3530-4ca3-83e8-76742496d45b') THEN
        RAISE NOTICE '✓ Test branch exists';
    ELSE
        RAISE NOTICE '✗ Test branch missing';
    END IF;

    -- Verify test users exist
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'testadmin@microflow.com') THEN
        RAISE NOTICE '✓ Test admin user exists';
    ELSE
        RAISE NOTICE '✗ Test admin user missing';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'manager@gmail.com') THEN
        RAISE NOTICE '✓ Test manager user exists';
    ELSE
        RAISE NOTICE '✗ Test manager user missing';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'collection@gmail.com') THEN
        RAISE NOTICE '✓ Test collection agent exists';
    ELSE
        RAISE NOTICE '✗ Test collection agent missing';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'customer@gmail.com') THEN
        RAISE NOTICE '✓ Test customer user exists';
    ELSE
        RAISE NOTICE '✗ Test customer user missing';
    END IF;

    -- Count total profiles
    RAISE NOTICE 'Total profiles: %', (SELECT COUNT(*) FROM public.profiles WHERE org_id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9');
    RAISE NOTICE 'Total auth users: %', (SELECT COUNT(*) FROM auth.users WHERE email LIKE '%microflow.com' OR email LIKE '%gmail.com');

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '  Staging Setup Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Login Credentials:';
    RAISE NOTICE '  Executive Admin: testadmin@microflow.com / password123';
    RAISE NOTICE '  Branch Manager: manager@gmail.com / password123';
    RAISE NOTICE '  Collection Agent: collection@gmail.com / password123';
    RAISE NOTICE '  Customer: customer@gmail.com / password123';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Run: .\scripts\switch-env.bat staging';
    RAISE NOTICE '2. Run: .\scripts\dev.ps1';
END $$;
