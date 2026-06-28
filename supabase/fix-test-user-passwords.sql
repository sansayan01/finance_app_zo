-- ============================================
-- MicroFlow Pro - Create Test Users (Staging)
-- ============================================
-- After running this script, set passwords manually
-- in the Supabase Dashboard > Authentication > Users
-- ============================================
-- Dashboard: https://supabase.com/dashboard/project/mirdnsifontxoccjwgak/auth/users
-- ============================================

-- STEP 1: Clean up any broken/orphaned data
DELETE FROM auth.refresh_tokens WHERE user_id IN (
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
    'd4444444-4444-4444-4444-444444444444'
);
DELETE FROM auth.mfa_factors WHERE user_id IN (
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
    'd4444444-4444-4444-4444-444444444444'
);
DELETE FROM auth.identities WHERE user_id IN (
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
    'd4444444-4444-4444-4444-444444444444'
);
DELETE FROM auth.users WHERE id IN (
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
    'd4444444-4444-4444-4444-444444444444'
);
DELETE FROM public.profiles WHERE user_id IN (
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
    'd4444444-4444-4444-4444-444444444444'
);
DELETE FROM public.branches WHERE org_id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9';
DELETE FROM public.organizations WHERE id = 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9';

-- STEP 2: Create org and branch
INSERT INTO public.organizations (id, name, slug, status, created_at)
VALUES ('dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', 'Test Org', 'test-org', 'active', now());

INSERT INTO public.branches (id, org_id, name, code, status, created_at)
VALUES ('769d81ce-3530-4ca3-83e8-76742496d45b', 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', 'Test Branch', 'TB001', 'active', now());

-- STEP 3: Create auth users (password will be set via Dashboard)
-- Using a temporary placeholder password hash - will be overwritten via Dashboard
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'testadmin@microflow.com', '$2a$10$placeholder', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Admin"}', now(), now()),
    ('b2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'manager@gmail.com', '$2a$10$placeholder', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Branch Manager"}', now(), now()),
    ('c3333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'collection@gmail.com', '$2a$10$placeholder', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Collection Agent"}', now(), now()),
    ('d4444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'customer@gmail.com', '$2a$10$placeholder', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Customer"}', now(), now());

-- STEP 4: Create auth identities
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
VALUES
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', '{"sub":"a1111111-1111-1111-1111-111111111111","email":"testadmin@microflow.com","email_verified":true}', 'email', 'testadmin@microflow.com', now(), now()),
    (gen_random_uuid(), 'b2222222-2222-2222-2222-222222222222', '{"sub":"b2222222-2222-2222-2222-222222222222","email":"manager@gmail.com","email_verified":true}', 'email', 'manager@gmail.com', now(), now()),
    (gen_random_uuid(), 'c3333333-3333-3333-3333-333333333333', '{"sub":"c3333333-3333-3333-3333-333333333333","email":"collection@gmail.com","email_verified":true}', 'email', 'collection@gmail.com', now(), now()),
    (gen_random_uuid(), 'd4444444-4444-4444-4444-444444444444', '{"sub":"d4444444-4444-4444-4444-444444444444","email":"customer@gmail.com","email_verified":true}', 'email', 'customer@gmail.com', now(), now());

-- STEP 5: Create profiles
INSERT INTO public.profiles (user_id, email, full_name, role, org_id, branch_id, status, is_active)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'testadmin@microflow.com', 'Test Admin', 'executiveAdmin', 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', null, 'active', true),
    ('b2222222-2222-2222-2222-222222222222', 'manager@gmail.com', 'Branch Manager', 'manager', 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', '769d81ce-3530-4ca3-83e8-76742496d45b', 'active', true),
    ('c3333333-3333-3333-3333-333333333333', 'collection@gmail.com', 'Collection Agent', 'collectionAgent', 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', '769d81ce-3530-4ca3-83e8-76742496d45b', 'active', true),
    ('d4444444-4444-4444-4444-444444444444', 'customer@gmail.com', 'Test Customer', 'customer', 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9', '769d81ce-3530-4ca3-83e8-76742496d45b', 'active', true);
