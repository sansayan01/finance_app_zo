-- =============================================
-- OPERATIONS SCHEMA
-- =============================================

-- System Status
CREATE TABLE system_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Incident
  incident_number TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT DEFAULT 'incident', -- incident, maintenance
  
  -- Affected
  affected_components TEXT[] NOT NULL,
  affected_org_ids UUID[],
  
  -- Status
  status TEXT DEFAULT 'investigating', -- investigating, identified, monitoring, resolved
  severity TEXT DEFAULT 'minor', -- minor, major, critical
  
  -- Timeline
  started_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  resolved_at TIMESTAMP WITH TIME ZONE,
  
  -- Updates
  updates JSONB DEFAULT '[]'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Scheduled Maintenance
CREATE TABLE scheduled_maintenance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  title TEXT NOT NULL,
  description TEXT,
  
  -- Schedule
  scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
  scheduled_end TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Affected
  affected_components TEXT[],
  affected_org_ids UUID[],
  
  -- Status
  status TEXT DEFAULT 'scheduled', -- scheduled, in_progress, completed, cancelled
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Uptime Monitoring
CREATE TABLE uptime_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  service TEXT NOT NULL,
  region TEXT NOT NULL,
  
  -- Check
  response_time_ms INTEGER,
  status_code INTEGER,
  success BOOLEAN NOT NULL,
  
  checked_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Error Tracking
CREATE TABLE error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Error
  error_type TEXT NOT NULL,
  error_message TEXT,
  stack_trace TEXT,
  
  -- Context
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  request_url TEXT,
  request_method TEXT,
  
  -- Environment
  platform TEXT,
  app_version TEXT,
  device_info JSONB,
  
  -- Fingerprinting (for grouping)
  fingerprint TEXT,
  occurrence_count INTEGER DEFAULT 1,
  first_occurred_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_occurred_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Status
  status TEXT DEFAULT 'unresolved', -- unresolved, resolved, ignored
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Help Articles
CREATE TABLE help_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Article
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  tags TEXT[],
  
  -- Stats
  view_count INTEGER DEFAULT 0,
  helpful_count INTEGER DEFAULT 0,
  not_helpful_count INTEGER DEFAULT 0,
  
  -- Status
  status TEXT DEFAULT 'published', -- draft, published, archived
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Video Tutorials
CREATE TABLE video_tutorials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Video
  title TEXT NOT NULL,
  description TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  duration_seconds INTEGER,
  
  -- Categorization
  category TEXT NOT NULL,
  tags TEXT[],
  
  -- Stats
  view_count INTEGER DEFAULT 0,
  
  -- Status
  status TEXT DEFAULT 'published',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_system_status_status ON system_status(status);
CREATE INDEX idx_scheduled_maintenance_start ON scheduled_maintenance(scheduled_start);
CREATE INDEX idx_uptime_checks_service ON uptime_checks(service, checked_at);
CREATE INDEX idx_error_logs_org ON error_logs(org_id);
CREATE INDEX idx_error_logs_fingerprint ON error_logs(fingerprint);
CREATE INDEX idx_help_articles_category ON help_articles(category);
CREATE INDEX idx_video_tutorials_category ON video_tutorials(category);

-- Enable RLS
ALTER TABLE system_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE uptime_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE help_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_tutorials ENABLE ROW LEVEL SECURITY;

-- Generate incident number
CREATE OR REPLACE FUNCTION generate_incident_number()
RETURNS TEXT AS $$
DECLARE
  v_number TEXT;
BEGIN
  v_number := 'INC-' || to_char(now(), 'YYYYMMDD') || '-' || 
    lpad((nextval('incident_number_seq') % 10000)::TEXT, 4, '0');
  RETURN v_number;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS incident_number_seq;

-- =============================================
-- END OF OPERATIONS SCHEMA
-- =============================================
