-- =====================================================
-- FIX: ADD ORG_ID TO STAFF PORTAL TABLES
-- =====================================================
-- Run this in your Supabase SQL Editor to fix multi-tenancy
-- for the Staff Portal tables.
-- =====================================================

DO $$
BEGIN
    -- 1. Branches
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'branches' AND column_name = 'org_id') THEN
        ALTER TABLE public.branches ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_branches_org ON public.branches(org_id);
    END IF;

    -- 2. Staff Profiles
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff_profiles' AND column_name = 'org_id') THEN
        ALTER TABLE public.staff_profiles ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_staff_profiles_org ON public.staff_profiles(org_id);
    END IF;

    -- 3. Collections
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'collections' AND column_name = 'org_id') THEN
        ALTER TABLE public.collections ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_collections_org ON public.collections(org_id);
    END IF;

    -- 4. Savings Collections
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'savings_collections' AND column_name = 'org_id') THEN
        ALTER TABLE public.savings_collections ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_savings_collections_org ON public.savings_collections(org_id);
    END IF;

    -- 5. Activity Logs (Staff)
    -- Note: activity_logs might already have org_id from migration_multi_tenant.sql
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'activity_logs' AND column_name = 'org_id') THEN
        ALTER TABLE public.activity_logs ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_activity_logs_org ON public.activity_logs(org_id);
    END IF;

    -- 6. Wallet
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff_wallet' AND column_name = 'org_id') THEN
        ALTER TABLE public.staff_wallet ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 7. Wallet Transactions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wallet_transactions' AND column_name = 'org_id') THEN
        ALTER TABLE public.wallet_transactions ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 8. Collection Targets
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'collection_targets' AND column_name = 'org_id') THEN
        ALTER TABLE public.collection_targets ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 9. Visit Logs
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'visit_logs' AND column_name = 'org_id') THEN
        ALTER TABLE public.visit_logs ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 10. Offline Sync Queue
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'offline_sync_queue' AND column_name = 'org_id') THEN
        ALTER TABLE public.offline_sync_queue ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 11. Staff Streaks
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff_streaks' AND column_name = 'org_id') THEN
        ALTER TABLE public.staff_streaks ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

    -- 12. Staff Notifications
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff_notifications' AND column_name = 'org_id') THEN
        ALTER TABLE public.staff_notifications ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;

END $$;

-- Update existing records to default org if needed
-- UPDATE public.branches SET org_id = '00000000-0000-0000-0000-000000000001'::uuid WHERE org_id IS NULL;
-- UPDATE public.staff_profiles SET org_id = '00000000-0000-0000-0000-000000000001'::uuid WHERE org_id IS NULL;
