-- =====================================================
-- CRITICAL FIX: PROFILES & STAFF CREATION
-- MicroFlow Pro - Multi-Tenant SaaS
-- =====================================================
-- This fixes the issues preventing branch managers, 
-- collection agents, and customers from being created.
-- =====================================================

-- =====================================================
-- ISSUE 1: PROFILES TABLE MISSING COLUMNS
-- =====================================================

-- Add missing columns to profiles table
DO $$
BEGIN
    -- Status column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'status') THEN
        ALTER TABLE public.profiles ADD COLUMN status TEXT DEFAULT 'active' 
            CHECK (status IN ('active', 'inactive', 'suspended', 'on_leave', 'pending'));
    END IF;
    
    -- Staff code column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'staff_code') THEN
        ALTER TABLE public.profiles ADD COLUMN staff_code TEXT UNIQUE;
    END IF;
    
    -- Branch ID (might already exist from branches_schema.sql)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'branch_id') THEN
        ALTER TABLE public.profiles ADD COLUMN branch_id UUID 
            REFERENCES public.branches(id) ON DELETE SET NULL;
    END IF;
    
    -- Org ID (might already exist from migration_multi_tenant.sql)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'org_id') THEN
        ALTER TABLE public.profiles ADD COLUMN org_id UUID 
            REFERENCES public.organizations(id) ON DELETE SET NULL;
    END IF;
    
    -- Phone column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'phone') THEN
        ALTER TABLE public.profiles ADD COLUMN phone TEXT;
    END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_staff_code ON public.profiles(staff_code);
CREATE INDEX IF NOT EXISTS idx_profiles_branch ON public.profiles(branch_id);

-- =====================================================
-- ISSUE 2: FIX ROLE CHECK CONSTRAINT
-- =====================================================

-- Drop the old constraint and add the new one with correct roles
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('superAdmin', 'executiveAdmin', 'manager', 'collectionAgent', 'customer'));

-- =====================================================
-- ISSUE 3: FIX RLS POLICIES FOR PROFILES
-- =====================================================

-- Drop old policies
DROP POLICY IF EXISTS org_insert_own ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- New policies that allow admins to create staff profiles

-- SELECT: Users can see profiles in their org
CREATE POLICY profiles_select ON public.profiles FOR SELECT
    USING (
        org_id = public.get_user_org_id() 
        OR user_id = auth.uid()
    );

-- INSERT: Users can create their own profile OR admins can create staff profiles
CREATE POLICY profiles_insert ON public.profiles FOR INSERT
    WITH CHECK (
        -- User creating their own profile
        user_id = auth.uid()
        OR
        -- Admin creating staff profile (must be in same org)
        (
            org_id = public.get_user_org_id()
            AND public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager')
        )
    );

-- UPDATE: Users can update their own profile OR admins can update staff
CREATE POLICY profiles_update ON public.profiles FOR UPDATE
    USING (
        user_id = auth.uid()
        OR
        (
            org_id = public.get_user_org_id()
            AND public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager')
        )
    )
    WITH CHECK (
        user_id = auth.uid()
        OR
        (
            org_id = public.get_user_org_id()
            AND public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager')
        )
    );

-- DELETE: Only admins can delete profiles
CREATE POLICY profiles_delete ON public.profiles FOR DELETE
    USING (
        org_id = public.get_user_org_id()
        AND public.get_user_role() IN ('superAdmin', 'executiveAdmin')
    );

-- =====================================================
-- ISSUE 4: MAKE user_id NULLABLE IN PROFILES
-- =====================================================
-- This allows creating profiles for staff without auth users
-- They can later be linked to auth users when they sign up

ALTER TABLE public.profiles ALTER COLUMN user_id DROP NOT NULL;

-- =====================================================
-- ISSUE 5: FIX MEMBERS TABLE FOR CUSTOMER CREATION
-- =====================================================

-- Ensure members table has required columns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'org_id') THEN
        ALTER TABLE public.members ADD COLUMN org_id UUID 
            REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'branch_id') THEN
        ALTER TABLE public.members ADD COLUMN branch_id UUID 
            REFERENCES public.branches(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'full_name') THEN
        ALTER TABLE public.members ADD COLUMN full_name TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'phone') THEN
        ALTER TABLE public.members ADD COLUMN phone TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'member_id') THEN
        ALTER TABLE public.members ADD COLUMN member_id TEXT UNIQUE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'members' AND column_name = 'kyc_status') THEN
        ALTER TABLE public.members ADD COLUMN kyc_status TEXT DEFAULT 'pending'
            CHECK (kyc_status IN ('pending', 'verified', 'rejected', 'notSubmitted'));
    END IF;
END $$;

-- Create indexes for members
CREATE INDEX IF NOT EXISTS idx_members_org ON public.members(org_id);
CREATE INDEX IF NOT EXISTS idx_members_branch ON public.members(branch_id);
CREATE INDEX IF NOT EXISTS idx_members_member_id ON public.members(member_id);

-- =====================================================
-- ISSUE 6: FIX BRANCHES TABLE
-- =====================================================

-- Ensure branches table has org_id
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'branches' AND column_name = 'org_id') THEN
        ALTER TABLE public.branches ADD COLUMN org_id UUID 
            REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'branches' AND column_name = 'zone') THEN
        ALTER TABLE public.branches ADD COLUMN zone TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'branches' AND column_name = 'district') THEN
        ALTER TABLE public.branches ADD COLUMN district TEXT;
    END IF;
END $$;

-- Drop unique constraint on code if it exists (it should be unique per org)
ALTER TABLE public.branches DROP CONSTRAINT IF EXISTS branches_code_key;

-- Add unique constraint for code within org
ALTER TABLE public.branches ADD CONSTRAINT branches_org_code_unique 
    UNIQUE (org_id, code);

-- =====================================================
-- ISSUE 7: FIX ORGANIZATIONS TABLE
-- =====================================================

-- Add missing columns to organizations
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'display_name') THEN
        ALTER TABLE public.organizations ADD COLUMN display_name TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'address') THEN
        ALTER TABLE public.organizations ADD COLUMN address TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'city') THEN
        ALTER TABLE public.organizations ADD COLUMN city TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'state') THEN
        ALTER TABLE public.organizations ADD COLUMN state TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'pincode') THEN
        ALTER TABLE public.organizations ADD COLUMN pincode TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'gst_number') THEN
        ALTER TABLE public.organizations ADD COLUMN gst_number TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'phone') THEN
        ALTER TABLE public.organizations ADD COLUMN phone TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'email') THEN
        ALTER TABLE public.organizations ADD COLUMN email TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'brand_color') THEN
        ALTER TABLE public.organizations ADD COLUMN brand_color TEXT DEFAULT '#1976D2';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'trial_ends_at') THEN
        ALTER TABLE public.organizations ADD COLUMN trial_ends_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- =====================================================
-- ISSUE 8: FIX RLS FOR BRANCHES
-- =====================================================

DROP POLICY IF EXISTS branches_insert ON public.branches;
DROP POLICY IF EXISTS "branches_select" ON public.branches;

CREATE POLICY branches_select ON public.branches FOR SELECT
    USING (org_id = public.get_user_org_id());

CREATE POLICY branches_insert ON public.branches FOR INSERT
    WITH CHECK (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager')
    );

CREATE POLICY branches_update ON public.branches FOR UPDATE
    USING (
        org_id = public.get_user_org_id()
        AND public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager')
    );

-- =====================================================
-- ISSUE 9: FIX RLS FOR MEMBERS
-- =====================================================

DROP POLICY IF EXISTS org_insert ON public.members;

CREATE POLICY members_insert ON public.members FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

-- =====================================================
-- ISSUE 10: CREATE STORAGE BUCKET FOR BRAND ASSETS
-- =====================================================

-- Create brand-assets storage bucket if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access to brand assets
CREATE POLICY brand_assets_public_read ON storage.objects FOR SELECT
    USING (bucket_id = 'brand-assets');

-- Allow authenticated users to upload to their org folder
CREATE POLICY brand_assets_upload ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'brand-assets' 
        AND auth.uid() IS NOT NULL
    );

-- =====================================================
-- VERIFICATION QUERIES (Run these to verify)
-- =====================================================
-- SELECT column_name, data_type FROM information_schema.columns 
--     WHERE table_name = 'profiles' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns 
--     WHERE table_name = 'members' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns 
--     WHERE table_name = 'branches' ORDER BY ordinal_position;
-- SELECT * FROM pg_policies WHERE tablename = 'profiles';

-- =====================================================
-- END OF CRITICAL FIX
-- =====================================================
