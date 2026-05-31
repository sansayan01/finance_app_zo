-- =====================================================
-- ADD FATHER NAME COLUMN TO PROFILES & MEMBERS TABLES
-- MicroFlow Pro
-- =====================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS father_name TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS father_name TEXT;

-- =====================================================
-- END OF MIGRATION
-- =====================================================
