-- =============================================
-- WHITE-LABELING SCHEMA
-- =============================================

-- Organization Branding
CREATE TABLE org_branding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE UNIQUE,
  
  -- Logo URLs (stored in Supabase Storage)
  logo_url TEXT,
  logo_dark_url TEXT,
  favicon_url TEXT,
  
  -- Colors
  primary_color TEXT DEFAULT '#3B82F6',
  secondary_color TEXT DEFAULT '#1E40AF',
  accent_color TEXT DEFAULT '#10B981',
  background_color TEXT DEFAULT '#FFFFFF',
  text_color TEXT DEFAULT '#1F2937',
  
  -- Typography
  font_family TEXT DEFAULT 'Inter',
  heading_font TEXT,
  
  -- Custom Domain
  custom_domain TEXT UNIQUE,
  domain_verified BOOLEAN DEFAULT false,
  domain_verification_token TEXT,
  
  -- Email Branding
  email_header_text TEXT,
  email_footer_text TEXT,
  email_signature TEXT,
  
  -- Login Page
  login_background_url TEXT,
  login_title TEXT,
  login_subtitle TEXT,
  login_button_text TEXT DEFAULT 'Sign In',
  
  -- Feature Flags (org-specific)
  features JSONB DEFAULT '{
    "chatbot": true,
    "analytics": true,
    "api_access": false,
    "white_label": false,
    "custom_domain": false,
    "sso": false,
    "audit_logs": false
  }'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Custom Domain Verification
CREATE TABLE custom_domains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  domain TEXT NOT NULL UNIQUE,
  verification_token TEXT NOT NULL,
  verification_method TEXT DEFAULT 'dns', -- dns, file
  verified BOOLEAN DEFAULT false,
  ssl_provisioned BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'pending', -- pending, verifying, active, failed
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  verified_at TIMESTAMP WITH TIME ZONE
);

-- Email Templates (Customizable)
CREATE TABLE email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  template_type TEXT NOT NULL, -- invitation, password_reset, collection_reminder, etc.
  subject TEXT NOT NULL,
  html_body TEXT NOT NULL,
  text_body TEXT,
  variables TEXT[], -- Available variables for this template
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  UNIQUE(org_id, template_type)
);

-- Reseller Program
CREATE TABLE reseller_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT,
  website TEXT,
  commission_rate DECIMAL(5,2) DEFAULT 15.00, -- Percentage
  status TEXT DEFAULT 'pending', -- pending, approved, rejected, suspended
  total_referrals INTEGER DEFAULT 0,
  total_earnings DECIMAL(12,2) DEFAULT 0.00,
  paid_earnings DECIMAL(12,2) DEFAULT 0.00,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  approved_at TIMESTAMP WITH TIME ZONE
);

-- Reseller Referrals
CREATE TABLE reseller_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reseller_id UUID REFERENCES reseller_accounts(id) ON DELETE CASCADE,
  referred_org_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  referral_code TEXT UNIQUE NOT NULL,
  discount_percent INTEGER DEFAULT 10, -- Discount for the referred org
  commission_earned DECIMAL(12,2) DEFAULT 0.00,
  status TEXT DEFAULT 'pending', -- pending, converted, paid
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  converted_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes
CREATE INDEX idx_org_branding_org ON org_branding(org_id);
CREATE INDEX idx_custom_domains_org ON custom_domains(org_id);
CREATE INDEX idx_custom_domains_domain ON custom_domains(domain);
CREATE INDEX idx_email_templates_org ON email_templates(org_id);
CREATE INDEX idx_reseller_accounts_user ON reseller_accounts(user_id);
CREATE INDEX idx_reseller_referrals_code ON reseller_referrals(referral_code);

-- Enable RLS
ALTER TABLE org_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE reseller_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reseller_referrals ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Org members can view branding"
  ON org_branding FOR SELECT
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Org admins can manage branding"
  ON org_branding FOR ALL
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Functions
CREATE OR REPLACE FUNCTION generate_verification_token()
RETURNS TEXT AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_default_branding()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO org_branding (org_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create branding when org is created
CREATE TRIGGER on_org_created_branding
  AFTER INSERT ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION create_default_branding();

-- Seed default email templates
INSERT INTO email_templates (org_id, template_type, subject, html_body, variables, is_default) VALUES
(null, 'invitation', 'You''re invited to join {{org_name}}', '<h1>Welcome!</h1><p>You have been invited to join {{org_name}} as a {{role}}.</p><p><a href="{{invite_link}}">Accept Invitation</a></p><p>This invitation expires in {{expires_in}} days.</p>', ARRAY['org_name', 'role', 'invite_link', 'expires_in'], true),
(null, 'password_reset', 'Reset your password', '<h1>Password Reset</h1><p>Click the link below to reset your password:</p><p><a href="{{reset_link}}">Reset Password</a></p><p>This link expires in {{expires_in}} hours.</p>', ARRAY['reset_link', 'expires_in'], true),
(null, 'collection_reminder', 'Payment Reminder from {{org_name}}', '<h1>Payment Reminder</h1><p>Dear {{member_name}},</p><p>Your EMI payment of ₹{{amount}} is due on {{due_date}}.</p><p>Please make the payment to avoid late fees.</p>', ARRAY['org_name', 'member_name', 'amount', 'due_date'], true),
(null, 'loan_disbursed', 'Your loan has been disbursed', '<h1>Loan Disbursed!</h1><p>Dear {{member_name}},</p><p>Your loan of ₹{{amount}} has been disbursed to your account.</p><p>EMI: ₹{{emi}} | Duration: {{tenure}} months</p>', ARRAY['member_name', 'amount', 'emi', 'tenure'], true);

-- =============================================
-- END OF WHITE-LABELING SCHEMA
-- =============================================
