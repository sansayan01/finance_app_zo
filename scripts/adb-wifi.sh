#!/bin/bash
# ─────────────────────────────────────────────────────────────
# MicroFlow Pro — Wireless ADB helper (phone testing)
#
# Usage:
#   ./scripts/adb-wifi.sh pair <IP:PORT> <PAIRING_CODE>   # one-time pairing
#   ./scripts/adb-wifi.sh connect <IP:PORT>               # connect (port = Wireless debugging screen)
#   ./scripts/adb-wifi.sh status                          # list devices
#   ./scripts/adb-wifi.sh disconnect                      # disconnect all wifi
#
# Phone side (Android 11+):
#   Settings > Developer options > Wireless debugging > ON
#   - Pair karte waqt: "Pair device with pairing code" kholo → IP:PORT + 6-digit code
#   - Connect karte waqt: main Wireless debugging screen ka IP:PORT
# ─────────────────────────────────────────────────────────────
set -e

ADB="/d/Android/Sdk/platform-tools/adb.exe"

cmd="${1:-status}"
case "$cmd" in
  pair)
    [ $# -eq 3 ] || { echo "Usage: $0 pair <IP:PORT> <PAIRING_CODE>"; exit 1; }
    echo "Pairing with $1 ..."
    "$ADB" pair "$1" "$2"
    ;;
  connect)
    [ $# -eq 2 ] || { echo "Usage: $0 connect <IP:PORT>"; exit 1; }
    "$ADB" connect "$1"
    "$ADB" devices
    ;;
  status)
    "$ADB" devices
    ;;
  disconnect)
    "$ADB" disconnect
    echo "All wifi devices disconnected"
    ;;
  *)
    echo "Usage: $0 {pair|connect|status|disconnect} ..."
    exit 1
    ;;
esac
