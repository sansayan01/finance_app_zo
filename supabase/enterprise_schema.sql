-- =============================================
-- ENTERPRISE SCHEMA
-- =============================================

-- SSO Configurations (SAML/OAuth)
CREATE TABLE sso_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE UNIQUE,
  
  -- Provider
  provider TEXT NOT NULL, -- okta, azure, google, onelogin, custom
  provider_name TEXT,
  
  -- SAML Configuration
  saml_entry_point TEXT,
  saml_certificate TEXT,
  saml_issuer TEXT,
  
  -- OAuth Configuration
  oauth_client_id TEXT,
  oauth_client_secret TEXT, -- Encrypted
  oauth_authorization_url TEXT,
  oauth_token_url TEXT,
  oauth_userinfo_url TEXT,
  
  -- Attribute Mapping
  attribute_mapping JSONB DEFAULT '{
    "email": "email",
    "name": "name",
    "role": "role"
  }'::jsonb,
  
  -- Settings
  auto_provision BOOLEAN DEFAULT true,
  default_role TEXT DEFAULT 'staff',
  allowed_domains TEXT[], -- e.g., ['company.com']
  
  -- Status
  status TEXT DEFAULT 'pending', -- pending, active, disabled
  last_used_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Who
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_email TEXT,
  user_name TEXT,
  
  -- What
  action TEXT NOT NULL, -- create, update, delete, login, export, etc.
  entity_type TEXT NOT NULL, -- member, loan, collection, user, etc.
  entity_id TEXT,
  
  -- Details
  description TEXT,
  old_values JSONB,
  new_values JSONB,
  
  -- Where
  ip_address INET,
  user_agent TEXT,
  device_type TEXT,
  
  -- When
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Classification
  severity TEXT DEFAULT 'info', -- info, warning, critical
  category TEXT -- authentication, data_access, data_modification, etc.
);

-- Data Residency Settings
CREATE TABLE data_residency_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE UNIQUE,
  
  -- Region
  primary_region TEXT NOT NULL DEFAULT 'us-east-1',
  backup_region TEXT,
  
  -- Compliance
  compliance_standards TEXT[] DEFAULT ARRAY['SOC2'],
  data_retention_days INTEGER DEFAULT 365,
  
  -- Encryption
  encryption_at_rest BOOLEAN DEFAULT true,
  encryption_in_transit BOOLEAN DEFAULT true,
  customer_managed_key BOOLEAN DEFAULT false,
  
  -- GDPR
  gdpr_enabled BOOLEAN DEFAULT false,
  dpo_contact_email TEXT,
  
  -- Data Processing
  cross_border_transfer BOOLEAN DEFAULT true,
  data_localization BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Data Deletion Requests
CREATE TABLE data_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  -- Request
  request_type TEXT NOT NULL, -- full_account, personal_data, specific_data
  status TEXT DEFAULT 'pending', -- pending, processing, completed, rejected
  reason TEXT,
  
  -- Processing
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  processed_at TIMESTAMP WITH TIME ZONE,
  processed_by UUID REFERENCES profiles(id),
  
  -- Details
  data_categories TEXT[],
  notes TEXT
);

-- SLA Agreements
CREATE TABLE sla_agreements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Plan
  plan_type TEXT NOT NULL, -- standard, premium, enterprise
  uptime_sla DECIMAL(5,2) DEFAULT 99.9,
  support_response_hours INTEGER DEFAULT 24,
  
  -- Support
  priority_support BOOLEAN DEFAULT false,
  dedicated_account_manager BOOLEAN DEFAULT false,
  support_channels TEXT[] DEFAULT ARRAY['email'],
  
  -- Billing
  monthly_fee DECIMAL(12,2),
  contract_start_date DATE,
  contract_end_date DATE,
  auto_renew BOOLEAN DEFAULT true,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Support Tickets
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Ticket
  ticket_number TEXT UNIQUE NOT NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  priority TEXT DEFAULT 'normal', -- low, normal, high, critical
  
  -- Status
  status TEXT DEFAULT 'open', -- open, in_progress, waiting_customer, resolved, closed
  
  -- Assignment
  assigned_to TEXT, -- Support agent
  category TEXT,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  first_response_at TIMESTAMP WITH TIME ZONE,
  resolved_at TIMESTAMP WITH TIME ZONE,
  
  -- SLA
  sla_breached BOOLEAN DEFAULT false
);

-- Support Ticket Messages
CREATE TABLE support_ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID REFERENCES support_tickets(id) ON DELETE CASCADE,
  
  -- Sender
  sender_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  sender_type TEXT NOT NULL, -- user, support
  sender_name TEXT,
  
  -- Message
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_sso_configurations_org ON sso_configurations(org_id);
CREATE INDEX idx_audit_logs_org ON audit_logs(org_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_data_residency_org ON data_residency_settings(org_id);
CREATE INDEX idx_data_deletion_org ON data_deletion_requests(org_id);
CREATE INDEX idx_sla_agreements_org ON sla_agreements(org_id);
CREATE INDEX idx_support_tickets_org ON support_tickets(org_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);
CREATE INDEX idx_support_ticket_messages_ticket ON support_ticket_messages(ticket_id);

-- Enable RLS
ALTER TABLE sso_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_residency_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_deletion_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE sla_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_ticket_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Org admins can manage SSO"
  ON sso_configurations FOR ALL
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Org members can view audit logs"
  ON audit_logs FOR SELECT
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

-- Audit Log Function (to be called by triggers or app)
CREATE OR REPLACE FUNCTION log_audit_event(
  p_org_id UUID,
  p_user_id UUID,
  p_action TEXT,
  p_entity_type TEXT,
  p_entity_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_severity TEXT DEFAULT 'info',
  p_category TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO audit_logs (
    org_id, user_id, action, entity_type, entity_id,
    description, old_values, new_values, severity, category
  ) VALUES (
    p_org_id, p_user_id, p_action, p_entity_type, p_entity_id,
    p_description, p_old_values, p_new_values, p_severity, p_category
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Automatic audit logging trigger example
CREATE OR REPLACE FUNCTION audit_members_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM log_audit_event(
      NEW.org_id,
      auth.uid(),
      'create',
      'member',
      NEW.id::TEXT,
      'Member created: ' || NEW.name,
      NULL,
      to_jsonb(NEW)
    );
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM log_audit_event(
      NEW.org_id,
      auth.uid(),
      'update',
      'member',
      NEW.id::TEXT,
      'Member updated: ' || NEW.name,
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM log_audit_event(
      OLD.org_id,
      auth.uid(),
      'delete',
      'member',
      OLD.id::TEXT,
      'Member deleted: ' || OLD.name,
      to_jsonb(OLD),
      NULL
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to members table
DROP TRIGGER IF EXISTS members_audit_trigger ON members;
CREATE TRIGGER members_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON members
  FOR EACH ROW EXECUTE FUNCTION audit_members_changes();

-- Generate ticket number function
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TEXT AS $$
DECLARE
  v_number TEXT;
BEGIN
  v_number := 'TKT-' || to_char(now(), 'YYYYMMDD') || '-' || 
    lpad((nextval('ticket_number_seq') % 10000)::TEXT, 4, '0');
  RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for ticket numbers
CREATE SEQUENCE IF NOT EXISTS ticket_number_seq;

-- =============================================
-- END OF ENTERPRISE SCHEMA
-- =============================================
