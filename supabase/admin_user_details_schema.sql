-- =====================================================
-- ADMIN USER DETAILS - SCHEMA ADDITIONS
-- =====================================================
-- Adds admin_notes table for internal admin annotations on users.
--
-- The audit timeline reuses public.audit_logs.
-- The compliance export reuses public.data_exports.
-- Force logout / delete reuse existing Edge Functions.
-- =====================================================

-- =====================================================
-- ADMIN NOTES (Internal admin-only annotations)
-- =====================================================
-- Each row is a free-form note an executive admin (or super admin) leaves
-- against a user record. Visible only to admins of the same org.

CREATE TABLE IF NOT EXISTS public.admin_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    -- The user (profile) the note is about. Could be a staff or customer
    -- profile, so we point at profiles.id rather than auth.users.id.
    user_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    -- The admin who authored the note (profile id of the author).
    author_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    body TEXT NOT NULL,
    pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_user
    ON public.admin_notes(user_profile_id);
CREATE INDEX IF NOT EXISTS idx_admin_notes_org
    ON public.admin_notes(org_id);
CREATE INDEX IF NOT EXISTS idx_admin_notes_created
    ON public.admin_notes(created_at DESC);

-- updated_at auto-bump
CREATE OR REPLACE FUNCTION public.touch_admin_notes_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_admin_notes_updated_at ON public.admin_notes;
CREATE TRIGGER trg_admin_notes_updated_at
BEFORE UPDATE ON public.admin_notes
FOR EACH ROW EXECUTE FUNCTION public.touch_admin_notes_updated_at();

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;

-- Drop any pre-existing policies (idempotent re-runs)
DROP POLICY IF EXISTS "Admins read admin_notes in org" ON public.admin_notes;
DROP POLICY IF EXISTS "Admins insert admin_notes in org" ON public.admin_notes;
DROP POLICY IF EXISTS "Admins update admin_notes in org" ON public.admin_notes;
DROP POLICY IF EXISTS "Admins delete admin_notes in org" ON public.admin_notes;

-- READ: any admin in the same org can read.
CREATE POLICY "Admins read admin_notes in org" ON public.admin_notes
    FOR SELECT USING (
        org_id = public.get_user_org_id()
        AND public.get_user_role() IN (
            'superAdmin', 'superadmin',
            'executiveAdmin', 'executiveadmin', 'admin'
        )
    );

-- INSERT: same admin scope.
CREATE POLICY "Admins insert admin_notes in org" ON public.admin_notes
    FOR INSERT WITH CHECK (
        org_id = public.get_user_org_id()
        AND public.get_user_role() IN (
            'superAdmin', 'superadmin',
            'executiveAdmin', 'executiveadmin', 'admin'
        )
    );

-- UPDATE: only the original author (or super admin) can edit.
CREATE POLICY "Admins update admin_notes in org" ON public.admin_notes
    FOR UPDATE USING (
        org_id = public.get_user_org_id()
        AND (
            public.get_user_role() IN ('superAdmin', 'superadmin')
            OR author_profile_id IN (
                SELECT id FROM public.profiles
                WHERE user_id = auth.uid()
            )
        )
    );

-- DELETE: only super admin or the original author.
CREATE POLICY "Admins delete admin_notes in org" ON public.admin_notes
    FOR DELETE USING (
        org_id = public.get_user_org_id()
        AND (
            public.get_user_role() IN ('superAdmin', 'superadmin')
            OR author_profile_id IN (
                SELECT id FROM public.profiles
                WHERE user_id = auth.uid()
            )
        )
    );

COMMENT ON TABLE public.admin_notes IS
    'Internal admin-only notes attached to a user profile. Visible only to '
    'admins of the same organization.';
