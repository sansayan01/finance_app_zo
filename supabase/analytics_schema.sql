-- =============================================
-- ANALYTICS SCHEMA
-- =============================================

-- Analytics Events (Aggregated)
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Event
  event_name TEXT NOT NULL,
  event_type TEXT NOT NULL, -- page_view, action, conversion, error
  
  -- Properties
  properties JSONB DEFAULT '{}'::jsonb,
  
  -- User context
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  session_id TEXT,
  
  -- Time
  occurred_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Dimensions
  date_key DATE NOT NULL,
  hour_key INTEGER,
  platform TEXT,
  app_version TEXT,
  country TEXT
);

-- Materialized view for daily stats
CREATE MATERIALIZED VIEW analytics_daily_stats AS
SELECT 
  org_id,
  date_key,
  event_type,
  event_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_id) as unique_users
FROM analytics_events
GROUP BY org_id, date_key, event_type, event_name;

-- Refresh daily
CREATE OR REPLACE FUNCTION refresh_analytics_daily()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics_daily_stats;
END;
$$ LANGUAGE plpgsql;

-- Organization Metrics (Pre-computed)
CREATE TABLE org_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE UNIQUE,
  
  -- Collections
  total_collections DECIMAL(15,2) DEFAULT 0,
  collections_this_month DECIMAL(12,2) DEFAULT 0,
  collections_growth DECIMAL(5,2) DEFAULT 0,
  collection_efficiency DECIMAL(5,2) DEFAULT 0,
  
  -- Loans
  total_loans_disbursed DECIMAL(15,2) DEFAULT 0,
  active_loans INTEGER DEFAULT 0,
  overdue_loans INTEGER DEFAULT 0,
  npa_count INTEGER DEFAULT 0,
  npa_percentage DECIMAL(5,2) DEFAULT 0,
  
  -- Members
  total_members INTEGER DEFAULT 0,
  active_members INTEGER DEFAULT 0,
  new_members_this_month INTEGER DEFAULT 0,
  member_retention_rate DECIMAL(5,2) DEFAULT 0,
  
  -- Staff
  total_staff INTEGER DEFAULT 0,
  active_staff INTEGER DEFAULT 0,
  staff_productivity DECIMAL(10,2) DEFAULT 0,
  
  -- Financial
  total_revenue DECIMAL(15,2) DEFAULT 0,
  revenue_this_month DECIMAL(12,2) DEFAULT 0,
  revenue_growth DECIMAL(5,2) DEFAULT 0,
  
  -- Computed at
  computed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Period
  period_start DATE,
  period_end DATE
);

-- Dashboard Widgets
CREATE TABLE dashboard_widgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Widget
  widget_type TEXT NOT NULL,
  title TEXT,
  config JSONB DEFAULT '{}'::jsonb,
  
  -- Position
  position_row INTEGER DEFAULT 0,
  position_col INTEGER DEFAULT 0,
  size_x INTEGER DEFAULT 1,
  size_y INTEGER DEFAULT 1,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Custom Reports
CREATE TABLE custom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  
  -- Report
  name TEXT NOT NULL,
  description TEXT,
  report_type TEXT NOT NULL, -- collection, loan, member, staff, financial
  
  -- Config
  filters JSONB DEFAULT '{}'::jsonb,
  columns JSONB DEFAULT '[]'::jsonb,
  aggregations JSONB DEFAULT '{}'::jsonb,
  
  -- Schedule
  schedule_frequency TEXT, -- daily, weekly, monthly
  schedule_recipients TEXT[],
  last_run_at TIMESTAMP WITH TIME ZONE,
  next_run_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_analytics_events_org ON analytics_events(org_id);
CREATE INDEX idx_analytics_events_date ON analytics_events(date_key);
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_org_metrics_org ON org_metrics(org_id);
CREATE INDEX idx_dashboard_widgets_user ON dashboard_widgets(user_id);
CREATE INDEX idx_custom_reports_org ON custom_reports(org_id);

-- Enable RLS
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_reports ENABLE ROW LEVEL SECURITY;

-- =============================================
-- END OF ANALYTICS SCHEMA
-- =============================================
