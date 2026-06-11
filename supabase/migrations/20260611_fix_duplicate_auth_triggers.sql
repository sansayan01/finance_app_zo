-- Fix: Drop duplicate/conflicting triggers on auth.users INSERT
-- These 3 triggers all fire on new auth user creation and conflict with each other

-- Trigger 1: No error handling, uses wrong type cast (NEW.id::text for UUID)
DROP TRIGGER IF EXISTS trg_handle_new_auth_user_profile ON auth.users;

-- Trigger 2: Notification trigger that depends on staff_profiles (may not exist)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Keep ONLY handle_new_auth_user_creates_profile which has:
-- - Proper error handling (BEGIN/EXCEPTION)
-- - Correct type casting (NEW.id for UUID)
-- - ON CONFLICT DO NOTHING
-- This is the only trigger needed for auto-creating profiles on auth user creation
