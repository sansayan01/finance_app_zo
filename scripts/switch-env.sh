#!/bin/bash
# Switch between environment configurations
# Usage: ./scripts/switch-env.sh [local|staging|production]

ENV=${1:-local}

case $ENV in
  local|staging|production)
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
    echo "Usage: ./scripts/switch-env.sh [local|staging|production]"
    echo ""
    echo "  local      - Local Supabase (http://127.0.0.1:54321)"
    echo "  staging    - Staging cloud Supabase"
    echo "  production - Production cloud Supabase"
    exit 1
    ;;
esac
