-- =============================================
-- GROWTH FEATURES SCHEMA
-- =============================================

-- Referrals
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  referrer_org_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  referrer_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  -- Code
  referral_code TEXT UNIQUE NOT NULL,
  
  -- Status
  status TEXT DEFAULT 'pending', -- pending, signed_up, converted, paid
  signup_date TIMESTAMP WITH TIME ZONE,
  conversion_date TIMESTAMP WITH TIME ZONE,
  
  -- Rewards
  reward_type TEXT DEFAULT 'credit', -- credit, discount, cash
  reward_amount DECIMAL(10,2) DEFAULT 500.00,
  reward_status TEXT DEFAULT 'pending', -- pending, credited, paid
  
  -- Discount for referred
  discount_percent INTEGER DEFAULT 20,
  discount_months INTEGER DEFAULT 3,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Marketplace Templates
CREATE TABLE marketplace_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_org_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  author_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  -- Template
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL, -- loan_type, workflow, report, integration
  type TEXT NOT NULL, -- template, integration, workflow
  
  -- Content
  template_data JSONB NOT NULL,
  preview_image_url TEXT,
  
  -- Stats
  downloads INTEGER DEFAULT 0,
  rating DECIMAL(3,2) DEFAULT 0.0,
  rating_count INTEGER DEFAULT 0,
  
  -- Pricing
  is_free BOOLEAN DEFAULT true,
  price DECIMAL(10,2) DEFAULT 0.00,
  
  -- Status
  status TEXT DEFAULT 'draft', -- draft, published, archived
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Template Reviews
CREATE TABLE template_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES marketplace_templates(id) ON DELETE CASCADE,
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  UNIQUE(template_id, user_id)
);

-- Announcements
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Content
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'info', -- info, feature, maintenance, warning
  
  -- Targeting
  target TEXT DEFAULT 'all', -- all, admins, staff
  target_org_ids UUID[],
  
  -- Scheduling
  scheduled_at TIMESTAMP WITH TIME ZONE,
  published_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  
  -- Status
  status TEXT DEFAULT 'draft', -- draft, scheduled, published, archived
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Feature Requests
CREATE TABLE feature_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  -- Request
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT, -- integration, feature, improvement, bug
  
  -- Voting
  votes INTEGER DEFAULT 0,
  voter_ids UUID[] DEFAULT ARRAY[]::UUID[],
  
  -- Status
  status TEXT DEFAULT 'under_review', -- under_review, planned, in_progress, completed, declined
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_referrals_org ON referrals(org_id);
CREATE INDEX idx_referrals_code ON referrals(referral_code);
CREATE INDEX idx_marketplace_templates_category ON marketplace_templates(category);
CREATE INDEX idx_marketplace_templates_status ON marketplace_templates(status);
CREATE INDEX idx_announcements_status ON announcements(status);
CREATE INDEX idx_feature_requests_status ON feature_requests(status);

-- Enable RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_requests ENABLE ROW LEVEL SECURITY;

-- Generate referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- END OF GROWTH FEATURES SCHEMA
-- =============================================
