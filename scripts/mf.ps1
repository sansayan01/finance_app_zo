# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  mf.ps1 — MicroFlow CLI (Windows PowerShell wrapper)
#  Calls the bash script via Git Bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir "mf"

# Find Git Bash
$gitBash = $null
$paths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
foreach ($p in $paths) {
    if (Test-Path $p) { $gitBash = $p; break }
}

if (-not $gitBash) {
    Write-Host "Git Bash not found. Install Git for Windows." -ForegroundColor Red
    exit 1
}

& $gitBash $bashScript @args
