-- Branch Manager Portal: Missing DB objects
-- Run this in Supabase SQL Editor

-- 1. pending_approvals table
CREATE TABLE IF NOT EXISTS pending_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  request_type TEXT NOT NULL DEFAULT 'loan',
  requested_by UUID REFERENCES profiles(id),
  member_id UUID REFERENCES members(id),
  amount NUMERIC,
  status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE pending_approvals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view org pending_approvals"
  ON pending_approvals FOR SELECT
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert org pending_approvals"
  ON pending_approvals FOR INSERT
  WITH CHECK (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update org pending_approvals"
  ON pending_approvals FOR UPDATE
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

-- 2. branch_targets table
CREATE TABLE IF NOT EXISTS branch_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  month INT NOT NULL,
  year INT NOT NULL,
  collection_target NUMERIC DEFAULT 0,
  disbursement_target NUMERIC DEFAULT 0,
  member_target INT DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(branch_id, month, year)
);

ALTER TABLE branch_targets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view org branch_targets"
  ON branch_targets FOR SELECT
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can manage org branch_targets"
  ON branch_targets FOR ALL
  USING (org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()));

-- 3. Fix get_branch_stats RPC to return all fields the model expects
CREATE OR REPLACE FUNCTION get_branch_stats(p_branch_id UUID)
RETURNS TABLE (
  total_staff INT,
  total_members INT,
  total_loans INT,
  active_loans INT,
  total_savings NUMERIC,
  total_disbursements NUMERIC,
  outstanding_amount NUMERIC,
  total_collections NUMERIC,
  overdue_loans INT,
  branch_name TEXT,
  branch_address TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::INT FROM profiles WHERE branch_id = p_branch_id AND role IN ('collectionAgent', 'manager')),
    (SELECT COUNT(*)::INT FROM members WHERE branch_id = p_branch_id),
    (SELECT COUNT(*)::INT FROM loans WHERE branch_id = p_branch_id),
    (SELECT COUNT(*)::INT FROM loans WHERE branch_id = p_branch_id AND status = 'active'),
    (SELECT COALESCE(SUM(balance), 0) FROM savings WHERE branch_id = p_branch_id),
    (SELECT COALESCE(SUM(amount), 0) FROM loans WHERE branch_id = p_branch_id),
    (SELECT COALESCE(SUM(outstanding_amount), 0) FROM loans WHERE branch_id = p_branch_id AND status = 'active'),
    (SELECT COALESCE(SUM(c.amount_collected), 0) FROM collections c JOIN profiles p ON c.staff_id = p.id WHERE p.branch_id = p_branch_id),
    (SELECT COUNT(*)::INT FROM loans WHERE branch_id = p_branch_id AND status = 'defaulted'),
    (SELECT name FROM branches WHERE id = p_branch_id),
    (SELECT COALESCE(address, '') FROM branches WHERE id = p_branch_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
