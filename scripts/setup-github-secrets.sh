#!/bin/bash
# Set up GitHub Secrets for the CI/CD pipeline
# Usage: ./scripts/setup-github-secrets.sh
# Prerequisites: gh auth login (GitHub CLI must be authenticated)

REPO="sansayan01/finance_app_zo"
GH="/c/Program Files/GitHub CLI/gh.exe"

STAGING_URL="https://mirdnsifontxoccjwgak.supabase.co"
STAGING_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pcmRuc2lmb250eG9jY2p3Z2FrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NzY5MTQsImV4cCI6MjA5ODE1MjkxNH0.pdRvYPlAAbsPFi4swCe1980l3OVHG4r7Z9tWtt9OX1Y"
PROD_URL="https://tccwdpsnuudzfyxfoohk.supabase.co"

echo "Setting GitHub Secrets for $REPO..."
echo ""

# 1. Android Keystore (base64-encoded)
KEYSTORE_B64=$(base64 -w 0 android/app/upload-keystore.jks)
"$GH" secret set ANDROID_KEYSTORE_BASE64 --body "$KEYSTORE_B64" -R "$REPO"
echo "Set ANDROID_KEYSTORE_BASE64"

# 2. Key Properties (base64-encoded)
KEYPROPS_B64=$(base64 -w 0 android/key.properties)
"$GH" secret set ANDROID_KEY_PROPERTIES --body "$KEYPROPS_B64" -R "$REPO"
echo "Set ANDROID_KEY_PROPERTIES"

# 3. Individual signing secrets (also needed by the workflow)
"$GH" secret set ANDROID_KEY_PASSWORD --body "microflow2026" -R "$REPO"
"$GH" secret set ANDROID_KEY_ALIAS --body "upload" -R "$REPO"
"$GH" secret set ANDROID_STORE_PASSWORD --body "microflow2026" -R "$REPO"
echo "Set ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_STORE_PASSWORD"

# 4. Supabase Production
"$GH" secret set PROD_SUPABASE_URL --body "$PROD_URL" -R "$REPO"
echo "Set PROD_SUPABASE_URL"
# Set production anon key from your .env.production value
PROD_ANON_KEY=$(grep "^SUPABASE_ANON_KEY=" .env.production | cut -d= -f2-)
if [ -n "$PROD_ANON_KEY" ]; then
  "$GH" secret set PROD_SUPABASE_ANON_KEY --body "$PROD_ANON_KEY" -R "$REPO"
  echo "Set PROD_SUPABASE_ANON_KEY"
fi

# 5. Supabase Staging
"$GH" secret set STAGING_SUPABASE_URL --body "$STAGING_URL" -R "$REPO"
"$GH" secret set STAGING_SUPABASE_ANON_KEY --body "$STAGING_ANON_KEY" -R "$REPO"
echo "Set STAGING_SUPABASE_URL and STAGING_SUPABASE_ANON_KEY"

# 5b. Supabase Service Role Key (used for APK upload)
SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
if [ -n "$SERVICE_ROLE_KEY" ]; then
  "$GH" secret set SUPABASE_SERVICE_ROLE_KEY --body "$SERVICE_ROLE_KEY" -R "$REPO"
  echo "Set SUPABASE_SERVICE_ROLE_KEY"
else
  echo "WARNING: SUPABASE_SERVICE_ROLE_KEY env var not set — set it manually in GitHub"
fi

# 7. iOS signing (base64-encoded certificate and provisioning profile)
# "$GH" secret set IOS_CERTIFICATE_P12_BASE64 --body "base64-of-your-dist-cert.p12" -R "$REPO"
# "$GH" secret set IOS_CERTIFICATE_PASSWORD --body "cert-password" -R "$REPO"
# "$GH" secret set IOS_PROVISIONING_PROFILE_BASE64 --body "base64-of-your-profile.mobileprovision" -R "$REPO"

echo ""
echo "Android signing secrets are set!"
echo "Please also add staging and other secrets manually in GitHub:"
echo " Settings > Secrets and variables > Actions > New repository secret"
echo ""
echo "Required secrets:"
echo " PROD_SUPABASE_URL           = https://tccwdpsnuudzfyxfoohk.supabase.co"
echo " PROD_SUPABASE_ANON_KEY      = (your production anon key)"
echo " SUPABASE_SERVICE_ROLE_KEY   = (from Supabase Dashboard > Settings > API)"
echo " STAGING_SUPABASE_URL        = https://your-staging-project.supabase.co"
echo " STAGING_SUPABASE_ANON_KEY   = (your staging anon key)"
echo " STAGING_POSTHOG_API_KEY     = (staging/optional PostHog key)"
echo " SENTRY_DSN                  = (optional, your Sentry DSN)"
echo " POSTHOG_API_KEY             = (optional, your PostHog key)"
echo " POSTHOG_HOST                = https://app.posthog.com"
echo " MAPBOX_ACCESS_TOKEN         = (optional, your Mapbox token)"
echo " IOS_CERTIFICATE_P12_BASE64  = (optional, for iOS builds)"
echo " IOS_CERTIFICATE_PASSWORD    = (optional, for iOS builds)"
echo " IOS_PROVISIONING_PROFILE_BASE64 = (optional, for iOS builds)"
