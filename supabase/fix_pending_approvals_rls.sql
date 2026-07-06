-- Fix: Add INSERT and UPDATE RLS policies for pending_approvals table
-- The table only had SELECT policy, blocking withdrawal request submissions

-- Allow authenticated users in the same org to INSERT withdrawal requests
CREATE POLICY "allow_insert_pending_approvals" ON "public"."pending_approvals"
  FOR INSERT
  WITH CHECK (("org_id" = "public"."get_user_org_id"()));

-- Allow authenticated users in the same org to UPDATE (approve/reject)
CREATE POLICY "allow_update_pending_approvals" ON "public"."pending_approvals"
  FOR UPDATE
  USING (("org_id" = "public"."get_user_org_id"()));
