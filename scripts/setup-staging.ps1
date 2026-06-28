# MicroFlow Pro - Staging Server Setup Script
# This script sets up the staging environment as the development/testing server
# Uses PowerShell syntax for Windows compatibility

param(
    [switch]$SkipSchema,
    [switch]$SkipTestUsers,
    [switch]$SkipVerification,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MicroFlow Pro - Staging Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$STAGING_URL = "https://mirdnsifontxoccjwgak.supabase.co"
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot

Write-Host "Staging Project: mirdnsifontxoccjwgak" -ForegroundColor Yellow
Write-Host "Staging URL: $STAGING_URL" -ForegroundColor Yellow
Write-Host ""

# Step 1: Apply Schema
if (-not $SkipSchema) {
    Write-Host "Step 1: Applying database schema..." -ForegroundColor Green

    $schemaFile = Join-Path $PROJECT_ROOT "supabase\migrations\20260628021905_consolidated_production_schema.sql"

    if (Test-Path $schemaFile) {
        Write-Host "  Found consolidated schema file" -ForegroundColor Gray
        Write-Host "  NOTE: Run this SQL manually in Supabase Dashboard SQL Editor:" -ForegroundColor Yellow
        Write-Host "  1. Go to: https://supabase.com/dashboard/project/mirdnsifontxoccjwgak/sql/new" -ForegroundColor Cyan
        Write-Host "  2. Copy the contents of: $schemaFile" -ForegroundColor Cyan
        Write-Host "  3. Execute the SQL" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "  ERROR: Schema file not found at $schemaFile" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Create Test Users
if (-not $SkipTestUsers) {
    Write-Host "Step 2: Creating test users..." -ForegroundColor Green

    # First, clean up existing test data
    $cleanupFile = Join-Path $PROJECT_ROOT "supabase\migrations\20260628040000_cleanup_auth_users.sql"
    if (Test-Path $cleanupFile) {
        Write-Host "  Running cleanup script..." -ForegroundColor Gray
        Write-Host "  NOTE: Run this SQL in Supabase Dashboard:" -ForegroundColor Yellow
        Write-Host "  File: $cleanupFile" -ForegroundColor Cyan
        Write-Host ""
    }

    # Then create test users
    $testUsersFile = Join-Path $PROJECT_ROOT "supabase\migrations\20260628040200_create_test_users.sql"
    if (Test-Path $testUsersFile) {
        Write-Host "  Creating test users..." -ForegroundColor Gray
        Write-Host "  NOTE: Run this SQL in Supabase Dashboard:" -ForegroundColor Yellow
        Write-Host "  File: $testUsersFile" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Step 3: Verify Environment Configuration
Write-Host "Step 3: Verifying environment configuration..." -ForegroundColor Green

$envFile = Join-Path $PROJECT_ROOT ".env"
$envStagingFile = Join-Path $PROJECT_ROOT ".env.staging"
$envProductionFile = Join-Path $PROJECT_ROOT ".env.production"
$envExampleFile = Join-Path $PROJECT_ROOT ".env.example"

# Check if .env exists and points to staging
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match "mirdnsifontxoccjwgak") {
        Write-Host "  ✓ .env is configured for staging" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ .env is not configured for staging" -ForegroundColor Yellow
        Write-Host "    Run: .\scripts\switch-env.bat staging" -ForegroundColor Cyan
    }
} else {
    Write-Host "  ⚠ .env file not found" -ForegroundColor Yellow
    Write-Host "    Run: .\scripts\switch-env.bat staging" -ForegroundColor Cyan
}

# Check .env.staging exists
if (Test-Path $envStagingFile) {
    Write-Host "  ✓ .env.staging exists" -ForegroundColor Green
} else {
    Write-Host "  ⚠ .env.staging not found" -ForegroundColor Yellow
}

# Step 4: Verify Supabase CLI Connection
Write-Host ""
Write-Host "Step 4: Verifying Supabase CLI connection..." -ForegroundColor Green

try {
    $linkResult = supabase projects list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Supabase CLI is authenticated" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Supabase CLI not authenticated or not installed" -ForegroundColor Yellow
        Write-Host "    Run: supabase login" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ⚠ Supabase CLI not available" -ForegroundColor Yellow
}

# Step 5: Create Development Workflow Document
Write-Host ""
Write-Host "Step 5: Creating development workflow..." -ForegroundColor Green

$workflowContent = @'
# MicroFlow Pro - Development Workflow

## Environment Architecture

- **Staging Server**: `https://mirdnsifontxoccjwgak.supabase.co` (Development & Testing)
- **Production Server**: `https://tccwdpsnuudzfyxfoohk.supabase.co` (Live)
- **Local Development**: Minimal - uses staging backend only

## Daily Development Flow

### 1. Start Development
```bash
# Switch to staging environment
.\scripts\switch-env.bat staging

# Run Flutter app (uses staging backend)
.\scripts\dev.ps1
```

### 2. Make Changes
- Edit code in `lib/` directory
- Flutter will hot-reload automatically
- All changes are tested against staging database

### 3. Test Changes
- Use test accounts in the staging database
- Verify all features work correctly
- Check for any database-related issues

### 4. Deploy to Staging
```bash
# Commit changes
git add .
git commit -m "feat: your feature description"

# Push to development branch (triggers staging build)
git push origin development
```

### 5. Verify Staging Build
- Check GitHub Actions for build status
- Test the staging APK on your device
- Verify all features work in production-like environment

### 6. Promote to Production
```bash
# Create a release tag
git tag v1.0.x
git push origin v1.0.x

# This triggers production build
```

## Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Executive Admin | testadmin@microflow.com | (set via Supabase Dashboard) |
| Branch Manager | manager@gmail.com | (set via Supabase Dashboard) |
| Collection Agent | collection@gmail.com | (set via Supabase Dashboard) |
| Customer | customer@gmail.com | (set via Supabase Dashboard) |

## Database Management

### Reset Staging Database
```bash
# Warning: This will delete all data!
supabase db reset --project-ref mirdnsifontxoccjwgak
```

### Apply Schema Changes
1. Edit the consolidated schema in `supabase/migrations/`
2. Run the migration SQL in Supabase Dashboard
3. Test thoroughly before deploying

### Backup Staging Data
```bash
# Export data (if needed)
supabase db dump --project-ref mirdnsifontxoccjwgak > backup.sql
```

## Troubleshooting

### App Won't Connect to Staging
1. Check `.env` file has correct staging URL
2. Verify internet connection
3. Check Supabase dashboard for service status

### Database Errors
1. Check Supabase logs in dashboard
2. Verify RLS policies are correct
3. Check for missing foreign key constraints

### Build Failures
1. Check GitHub Actions logs
2. Verify all dependencies are installed
3. Check for Dart/Flutter version compatibility

## Key Commands

```bash
# Environment switching
.\scripts\switch-env.bat staging
.\scripts\switch-env.bat production

# Flutter development
.\scripts\dev.ps1              # Run in Edge browser
.\scripts\dev.ps1 -Device windows  # Run in Windows desktop
.\scripts\dev-watch.ps1        # Auto hot-restart on file changes

# Supabase operations
supabase login                 # Authenticate
supabase projects list         # List projects
supabase db reset              # Reset database (DANGEROUS!)
```

## Notes

- **Staging is the primary development environment** - all development happens here
- **Production is only for live users** - never test directly on production
- **Local Supabase has been removed** - saves resources on older hardware
- **All test data lives in staging** - safe to reset when needed
'@

$workflowFile = Join-Path $PROJECT_ROOT "docs\DEVELOPMENT_WORKFLOW.md"
$docsDir = Join-Path $PROJECT_ROOT "docs"

if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
}

$workflowContent | Out-File -FilePath $workflowFile -Encoding UTF8
Write-Host "  ✓ Created development workflow guide" -ForegroundColor Green
Write-Host "    Location: $workflowFile" -ForegroundColor Gray

# Step 6: Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Apply the schema to staging database:" -ForegroundColor White
Write-Host "   - Go to: https://supabase.com/dashboard/project/mirdnsifontxoccjwgak/sql/new" -ForegroundColor Cyan
Write-Host "   - Execute: supabase\migrations\20260628021905_consolidated_production_schema.sql" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Create test users:" -ForegroundColor White
Write-Host "   - Execute: supabase\migrations\20260628040000_cleanup_auth_users.sql" -ForegroundColor Cyan
Write-Host "   - Execute: supabase\migrations\20260628040200_create_test_users.sql" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Set test user passwords in Supabase Dashboard:" -ForegroundColor White
Write-Host "   - Go to: Authentication > Users" -ForegroundColor Cyan
Write-Host "   - Set passwords for each test user" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Start developing:" -ForegroundColor White
Write-Host "   - Run: .\scripts\switch-env.bat staging" -ForegroundColor Cyan
Write-Host "   - Run: .\scripts\dev.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Read the workflow guide:" -ForegroundColor White
Write-Host "   - Location: docs\DEVELOPMENT_WORKFLOW.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "Staging Environment URLs:" -ForegroundColor Yellow
Write-Host "  Dashboard: https://supabase.com/dashboard/project/mirdnsifontxoccjwgak" -ForegroundColor Cyan
Write-Host "  API: https://mirdnsifontxoccjwgak.supabase.co" -ForegroundColor Cyan
Write-Host "  Studio: https://mirdnsifontxoccjwgak.supabase.co" -ForegroundColor Cyan
