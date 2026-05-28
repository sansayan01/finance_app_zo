-- SMS Notifications Table
-- Audit log for SMS payment receipts sent to customers

CREATE TABLE IF NOT EXISTS public.sms_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL,
  member_id UUID,
  member_phone TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  error_message TEXT,
  platform TEXT NOT NULL,
  sent_by UUID,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sms_notifications_org_id ON public.sms_notifications(org_id);
CREATE INDEX IF NOT EXISTS idx_sms_notifications_collection_id ON public.sms_notifications(collection_id);
CREATE INDEX IF NOT EXISTS idx_sms_notifications_status ON public.sms_notifications(status);
CREATE INDEX IF NOT EXISTS idx_sms_notifications_created_at ON public.sms_notifications(created_at DESC);

-- RLS
ALTER TABLE public.sms_notifications ENABLE ROW LEVEL SECURITY;

-- Org members can read their SMS logs
CREATE POLICY "sms_notifications_org_select" ON public.sms_notifications
  FOR SELECT USING (
    org_id IN (SELECT org_id FROM public.profiles WHERE id = auth.uid())
  );

-- Org members can insert SMS logs
CREATE POLICY "sms_notifications_org_insert" ON public.sms_notifications
  FOR INSERT WITH CHECK (
    org_id IN (SELECT org_id FROM public.profiles WHERE id = auth.uid())
  );

-- Super admin full access
CREATE POLICY "sms_notifications_super_admin" ON public.sms_notifications
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superAdmin')
  );

COMMENT ON TABLE public.sms_notifications IS 'Audit log for SMS payment receipts sent to customers from collector devices.';
