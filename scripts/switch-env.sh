#!/bin/bash
# Switch between environment configurations
# Usage: ./scripts/switch-env.sh [staging|production]
# NOTE: 'local' option removed — use staging for development.

ENV=${1:-staging}

case $ENV in
  staging|production)
    if [ -f ".env.$ENV" ]; then
      cp ".env.$ENV" ".env"
      mkdir -p assets
      cp ".env.$ENV" "assets/.env"
      echo "Switched to $ENV environment"
      echo "  SUPABASE_URL=$(grep SUPABASE_URL .env | head -1 | cut -d= -f2-)"
    else
      echo "Error: .env.$ENV not found"
      exit 1
    fi
    ;;
  *)
    echo "Usage: ./scripts/switch-env.sh [staging|production]"
    echo ""
    echo "  staging    - Staging cloud Supabase (development)"
    echo "  production - Production cloud Supabase (live)"
    exit 1
    ;;
esac
