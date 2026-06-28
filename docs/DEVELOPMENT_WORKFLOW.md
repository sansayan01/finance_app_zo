# MicroFlow Pro - Development Workflow

## Environment Architecture

- **Staging Server**: `https://mirdnsifontxoccjwgak.supabase.co` (Development & Testing)
- **Production Server**: `https://tccwdpsnuudzfyxfoohk.supabase.co` (Live)
- **Local Development**: Minimal - uses staging backend only

## Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Executive Admin | testadmin@microflow.com | password123 |
| Branch Manager | manager@gmail.com | password123 |
| Collection Agent | collection@gmail.com | password123 |
| Customer | customer@gmail.com | password123 |

## Daily Development Flow

### 1. Start Development
```bash
# Switch to staging environment
.\scripts\switch-env.bat staging

# Run Flutter app on Edge
.\scripts\dev.ps1

# Or run with auto hot-restart on file changes
.\scripts\dev-watch.ps1
```

### 2. Make Changes
- Edit code in `lib/` directory
- Flutter will hot-reload automatically
- All changes are tested against staging database

### 3. Deploy to Staging
```bash
# Commit changes
git add .
git commit -m "feat: your feature description"

# Push to development branch (triggers staging build)
git push origin development
```

### 4. Promote to Production
```bash
# Create a release tag
git tag v1.0.x
git push origin v1.0.x
```

## Database Management

### Reset Staging Database
```bash
# Warning: This will delete all data!
supabase db reset --project-ref mirdnsifontxoccjwgak
```

### Fix Test User Passwords
If login stops working, run `supabase/fix-test-user-passwords.sql` in the Supabase SQL Editor.

## Troubleshooting

### Can't Login
1. Make sure `.env` has staging URL: `.\scripts\switch-env.bat staging`
2. Run `supabase/fix-test-user-passwords.sql` in SQL Editor
3. Check Supabase dashboard > Authentication > Users for the account

### App Won't Connect
1. Check `.env` file has correct staging URL
2. Verify internet connection
3. Check Supabase dashboard for service status
