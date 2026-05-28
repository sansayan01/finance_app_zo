-- ==============================================
-- ADD ICON PRESET COLUMN TO ORGANIZATIONS
-- ==============================================
-- Run this in Supabase SQL Editor.
-- This adds the icon_preset column that stores which
-- bundled launcher icon theme the org has selected.
-- All org members will read this on login and apply
-- the icon to their device.

ALTER TABLE public.organizations
ADD COLUMN IF NOT EXISTS icon_preset TEXT DEFAULT 'default';

-- Add a comment for documentation
COMMENT ON COLUMN public.organizations.icon_preset IS 
  'Preset launcher icon theme ID. Valid values: default, bank_blue, savings_green, micro_orange, trust_purple, field_teal';

-- Ensure the column has a valid value constraint
ALTER TABLE public.organizations
ADD CONSTRAINT chk_icon_preset 
CHECK (icon_preset IN ('default', 'bank_blue', 'savings_green', 'micro_orange', 'trust_purple', 'field_teal'))
NOT VALID;

-- Validate the constraint (non-blocking on existing rows)
ALTER TABLE public.organizations VALIDATE CONSTRAINT chk_icon_preset;
