-- Add per-member SMS notification toggle
-- Default: true (all existing customers continue receiving SMS)
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS sms_enabled BOOLEAN DEFAULT true;
