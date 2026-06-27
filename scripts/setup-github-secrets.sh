#!/bin/bash
# Set up GitHub Secrets for the CI/CD pipeline
# Usage: ./scripts/setup-github-secrets.sh
# Prerequisites: gh auth login (GitHub CLI must be authenticated)

REPO="sansayan01/finance_app_zo"
GH="/c/Program Files/GitHub CLI/gh.exe"

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
echo ""
echo "Now set your Supabase secrets."
echo "Run these manually or edit this script with your values:"
echo ""

# Uncomment and fill in these values:
# "$GH" secret set PROD_SUPABASE_URL --body "https://tccwdpsnuudzfyxfoohk.supabase.co" -R "$REPO"
# "$GH" secret set PROD_SUPABASE_ANON_KEY --body "your-production-anon-key" -R "$REPO"
# "$GH" secret set SUPABASE_SERVICE_ROLE_KEY --body "your-service-role-key" -R "$REPO"

# 5. Telemetry
# "$GH" secret set SENTRY_DSN --body "your-sentry-dsn" -R "$REPO"
# "$GH" secret set POSTHOG_API_KEY --body "your-posthog-key" -R "$REPO"
# "$GH" secret set POSTHOG_HOST --body "https://app.posthog.com" -R "$REPO"

# 6. Mapbox
# "$GH" secret set MAPBOX_ACCESS_TOKEN --body "your-mapbox-token" -R "$REPO"

echo ""
echo "Android signing secrets are set!"
echo "Please set the remaining secrets manually in GitHub:"
echo "  Settings > Secrets and variables > Actions > New repository secret"
echo ""
echo "Required secrets:"
echo "  PROD_SUPABASE_URL       = https://tccwdpsnuudzfyxfoohk.supabase.co"
echo "  PROD_SUPABASE_ANON_KEY  = (your production anon key)"
echo "  SUPABASE_SERVICE_ROLE_KEY = (from Supabase Dashboard > Settings > API)"
echo "  SENTRY_DSN              = (optional, your Sentry DSN)"
echo "  POSTHOG_API_KEY         = (optional, your PostHog key)"
echo "  POSTHOG_HOST            = https://app.posthog.com"
echo "  MAPBOX_ACCESS_TOKEN     = (optional, your Mapbox token)"
