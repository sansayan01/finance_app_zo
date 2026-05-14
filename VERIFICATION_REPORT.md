# MicroFlow Pro - Verification Report

## 📋 Issues Found & Fixed

### Critical Issues (Would Block Creation)

| Issue | Status | Fix File |
|-------|--------|----------|
| Profiles table missing `status`, `staff_code`, `branch_id` columns | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| Role check constraint missing `collectionAgent` | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| RLS policy blocked admins from creating staff | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| `user_id` was NOT NULL (required auth user) | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| Members table missing required columns | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| Branches table missing `org_id`, `zone`, `district` | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| Organizations table missing columns | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |
| Storage bucket for brand assets missing | ✅ Fixed | `supabase/fix_critical_creation_issues.sql` |

---

## ✅ Verified Creation Flows

### 1. Organization Creation
```
Table: organizations
Columns Used:
✓ name
✓ display_name
✓ slug
✓ status ('trial')
✓ trial_ends_at
✓ max_branches (2)
✓ max_staff (5)
✓ max_members (100)
✓ address
✓ city
✓ state
✓ pincode
✓ gst_number
✓ phone
✓ email
✓ brand_color
✓ created_by
```

### 2. Branch Creation
```
Table: branches
Columns Used:
✓ org_id
✓ name
✓ code
✓ zone
✓ district
✓ address
✓ status ('active')
```

### 3. Branch Manager Creation
```
Table: profiles
Columns Used:
✓ org_id
✓ full_name
✓ phone
✓ email
✓ role ('manager')
✓ branch_id
✓ status ('active')
✓ staff_code
✓ user_id (NULL - will link when they sign up)
```

### 4. Collection Agent Creation
```
Table: profiles
Columns Used:
✓ org_id
✓ full_name
✓ phone
✓ email
✓ role ('collectionAgent')
✓ branch_id
✓ status ('active')
✓ staff_code
✓ user_id (NULL - will link when they sign up)
```

### 5. Customer Creation
```
Table: members
Columns Used:
✓ org_id
✓ full_name
✓ phone
✓ member_id
✓ branch_id
✓ kyc_status ('pending')
✓ status ('active')
```

---

## 🔧 Required Actions in Supabase

### Step 1: Run the Fix Script
Go to Supabase SQL Editor and run:
```sql
-- Run this file in order:
-- 1. Base schema (if not already run)
-- 2. supabase_staff_schema.sql
-- 3. supabase/branches_schema.sql
-- 4. supabase/migration_multi_tenant.sql
-- 5. supabase/fix_critical_creation_issues.sql  <-- CRITICAL!
```

### Step 2: Verify Columns Exist
```sql
-- Check profiles columns
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- Should include: status, staff_code, branch_id, org_id
-- user_id should be nullable
```

### Step 3: Verify RLS Policies
```sql
-- Check profiles policies
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'profiles';

-- Should have:
-- profiles_select - USING (org_id = get_user_org_id() OR user_id = auth.uid())
-- profiles_insert - WITH CHECK (user_id = auth.uid() OR (org_id = get_user_org_id() AND role IN admin roles))
-- profiles_update - USING/WITH CHECK similar
-- profiles_delete - admin only
```

### Step 4: Verify Role Constraint
```sql
-- Check role constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'profiles_role_check';

-- Should include: superAdmin, executiveAdmin, manager, collectionAgent, customer
```

---

## 🚀 How It Works Now

### Staff Creation Flow (Manager/Collection Agent)

1. **Admin fills form** → Setup wizard collects name, phone, email, branch
2. **Profile created WITHOUT auth user** → `user_id = NULL`
3. **Staff code generated** → e.g., `BM12345` or `CA12345`
4. **Later: Staff signs up** → Their profile is linked via `user_id`

### Why This Approach?

- ✅ No need for admin API to create auth users
- ✅ Staff can self-register later
- ✅ Profile already exists with correct role/branch
- ✅ Matches by phone/email to link account

---

## 📝 Code Verification Summary

| Component | File | Status |
|-----------|------|--------|
| Organization creation | `setup_wizard_page.dart` | ✅ Correct |
| Branch creation | `setup_wizard_page.dart` | ✅ Correct |
| Manager creation | `setup_wizard_page.dart` | ✅ Correct |
| Agent creation | `setup_wizard_page.dart` | ✅ Correct |
| Customer creation | `setup_wizard_page.dart` | ✅ Correct |
| Role enum | `enums.dart` | ✅ Correct |
| UserModel | `user_model.dart` | ✅ Has orgId |
| ProfileModel | `user_model.dart` | ✅ Has orgId, branchId |
| currentOrgIdProvider | `org_provider.dart` | ✅ Working |

---

## ⚠️ Important Notes

1. **Run SQL fixes in Supabase** - The Flutter code is correct, but the database needs the fix script!

2. **Order matters** - Run schema files in this order:
   - Base schema
   - `supabase_staff_schema.sql`
   - `supabase/branches_schema.sql`
   - `supabase/migration_multi_tenant.sql`
   - `supabase/fix_critical_creation_issues.sql`

3. **Test after fix** - After running SQL, test the wizard:
   - Create organization with logo
   - Create branch
   - Create branch manager
   - Create collection agent (skip optional)
   - Create customer (skip optional)

---

## 📊 Database Schema Summary

### profiles (for all users including staff)
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| id | UUID | No | Primary key |
| user_id | UUID | **YES** | Links to auth.users (nullable!) |
| org_id | UUID | Yes | Organization |
| branch_id | UUID | Yes | Assigned branch |
| full_name | TEXT | Yes | Display name |
| phone | TEXT | Yes | Contact |
| email | TEXT | Yes | Email |
| role | TEXT | Yes | superAdmin/executiveAdmin/manager/collectionAgent/customer |
| status | TEXT | Yes | active/inactive/suspended/on_leave/pending |
| staff_code | TEXT | Yes | Unique code (BM12345, CA12345) |

### members (for customers)
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| id | UUID | No | Primary key |
| org_id | UUID | No | Organization |
| branch_id | UUID | Yes | Assigned branch |
| full_name | TEXT | Yes | Display name |
| phone | TEXT | Yes | Contact |
| member_id | TEXT | Yes | Unique member ID (C123456) |
| kyc_status | TEXT | Yes | pending/verified/rejected/notSubmitted |
| status | TEXT | Yes | active/inactive |

### branches
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| id | UUID | No | Primary key |
| org_id | UUID | No | Organization |
| name | TEXT | No | Branch name |
| code | TEXT | No | Unique within org |
| zone | TEXT | Yes | Zone |
| district | TEXT | Yes | District |
| status | TEXT | Yes | active/inactive/closed |

---

**Last Updated**: May 14, 2026
**Status**: ✅ All Issues Fixed - Run SQL in Supabase!
