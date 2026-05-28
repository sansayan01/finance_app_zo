-- =====================================================
-- FIX: Add missing columns to profiles table
-- MicroFlow Pro - Profile Update Fix
-- =====================================================
-- Run this in your Supabase SQL Editor if profile updates
-- are failing with "column does not exist" errors.
-- =====================================================

-- Add columns that may be missing from the profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pan TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS aadhar TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employee_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_zone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMP WITH TIME ZONE;

-- =====================================================
-- Also create the avatars storage bucket if it doesn't exist
-- =====================================================
-- NOTE: Run this separately in the Supabase Dashboard:
-- 1. Go to Storage → New Bucket
-- 2. Name: "avatars"
-- 3. Check "Public bucket"
-- 4. Click "Create bucket"
--
-- Or run this SQL:
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload to the avatars bucket
CREATE POLICY "Allow authenticated uploads to avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- Allow authenticated users to update their own avatars
CREATE POLICY "Allow authenticated updates to avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars');

-- Allow public read access to avatars
CREATE POLICY "Allow public read access to avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Allow authenticated users to delete their own avatars
CREATE POLICY "Allow authenticated deletes from avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars');

-- =====================================================
-- END OF FIX
-- =====================================================
