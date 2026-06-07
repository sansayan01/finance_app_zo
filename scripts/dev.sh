#!/usr/bin/env bash
# ============================================================
# MicroFlow Pro - Live dev script (bash/Git Bash) - Edge default
# ============================================================
# Usage:
#   ./scripts/dev.sh              # run on Edge with hot reload
#   ./scripts/dev.sh --device web
#   ./scripts/dev.sh --device windows
# ============================================================

set -e

JDK="C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot"
DEVICE="edge"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device|-d) DEVICE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$PATH"

cyan() { printf "\033[36m%s\033[0m\n" "$*"; }

cyan "==> Starting Flutter on $DEVICE (press 'r' to hot reload, 'R' to restart, 'q' to quit)"
echo ""
echo "  Note: hot reload on web is a full page refresh (~3-5s), not state-preserving."
echo ""
flutter run -d "$DEVICE"
