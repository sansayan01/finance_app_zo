# Staging-Only Migrations

These migration files were applied only on the staging server and should
NEVER be pushed to production via `supabase db push`.

They have been moved here from `supabase/migrations/` to prevent accidental
execution on the production database.

## Files in this folder

| File | What it does | Why staging-only |
|------|-------------|------------------|
| 20260628040000_cleanup_auth_users.sql | Deletes broken auth users | Only needed for staging cleanup |
| 20260628040200_create_test_users.sql | Creates test users and org | Only for staging testing |
| 20260628060000_fix_loan_interest_rate...sql | Fixes a single staging loan | Only exists in staging |

These files are kept for reference but will not be used by `supabase db push`.
