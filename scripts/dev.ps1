# ============================================================
# MicroFlow Pro - Live dev script (PowerShell) - Edge default
# ============================================================
# Usage:
#   .\scripts\dev.ps1              # run on Edge with hot reload
#   .\scripts\dev.ps1 -Device web  # same as Edge
#   .\scripts\dev.ps1 -Device windows
# ============================================================

param(
    [string]$Device = "edge"
)

$ErrorActionPreference = "Stop"

# --- Env -------------------------------------------------------------------
$jdk = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
if (Test-Path $jdk) {
    $env:JAVA_HOME = $jdk
    $env:Path = "$jdk\bin;$env:Path"
}

# --- Helpers ---------------------------------------------------------------
function Write-Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  [!] $msg" -ForegroundColor Yellow }

# --- Run -------------------------------------------------------------------
Write-Step "Starting Flutter on $Device (press 'r' to hot reload, 'R' to restart, 'q' to quit)"
Write-Host ""
Write-Host "  Note: hot reload on web is a full page refresh (~3-5s), not state-preserving." -ForegroundColor DarkYellow
Write-Host ""
flutter run -d $Device
