-- ============================================================================
-- Migration: 20260629000000_create_app_updates_table.sql
--
-- Purpose:
-- Add a structured app_updates table (for both Android & iOS) and enable
-- Supabase Realtime on it so the UpdateWrapper/UpdateCheckResult stream
-- picks up new rows immediately after they are published.
--
-- Note: the table already existed in staging from earlier work, with these
-- columns: id, version, platform, release_notes, is_critical,
-- min_supported_version, published_at. This migration adds the missing
-- columns and the Realtime publication.
-- ============================================================================

-- 1. Idempotent column additions (safe if table was created earlier)
ALTER TABLE IF EXISTS public.app_updates
  ADD COLUMN IF NOT EXISTS download_url       text,
  ADD COLUMN IF NOT EXISTS apk_path           text,
  ADD COLUMN IF NOT EXISTS firebase_app_id    text,
  ADD COLUMN IF NOT EXISTS status             text NOT NULL DEFAULT 'active'
                              CHECK (status IN ('draft', 'active', 'archived')),
  ADD COLUMN IF NOT EXISTS is_mandatory       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS file_size_mb       numeric(6,2),
  ADD COLUMN IF NOT EXISTS updated_at         timestamptz NOT NULL
                              DEFAULT timezone('utc', now());

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_app_updates_platform_status
  ON public.app_updates(platform, status);

CREATE INDEX IF NOT EXISTS idx_app_updates_published
  ON public.app_updates(published_at DESC);

-- 3. RLS — public can read active rows, authenticated admins can write
ALTER TABLE public.app_updates ENABLE ROW LEVEL SECURITY;

-- Drop before recreating to keep things idempotent.
DROP POLICY IF EXISTS "Public can read active app updates" ON public.app_updates;
CREATE POLICY "Public can read active app updates"
  ON public.app_updates FOR SELECT
  USING (status = 'active');

DROP POLICY IF EXISTS "Admins can insert app updates" ON public.app_updates;
CREATE POLICY "Admins can insert app updates"
  ON public.app_updates FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM public.profiles
      WHERE role IN ('superAdmin', 'executiveAdmin', 'admin')
    )
  );

DROP POLICY IF EXISTS "Admins can update app updates" ON public.app_updates;
CREATE POLICY "Admins can update app updates"
  ON public.app_updates FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT user_id FROM public.profiles
      WHERE role IN ('superAdmin', 'executiveAdmin', 'admin')
    )
  );

DROP POLICY IF EXISTS "Authenticated can upsert app updates" ON public.app_updates;
CREATE POLICY "Authenticated can upsert app updates"
  ON public.app_updates FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT user_id FROM public.profiles
      WHERE role = 'superAdmin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM public.profiles
      WHERE role = 'superAdmin'
    )
  );

-- 4. Enable Realtime publication for app_updates
--    (idempotent: posting twice has the same effect)
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_updates;
