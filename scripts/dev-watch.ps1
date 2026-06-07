# ============================================================
# MicroFlow Pro - Auto hot-restart on file save
# ============================================================
# Starts `flutter run -d edge`, then watches lib/ for changes
# and sends hot restart to the running app via the VM service
# (the same protocol VS Code uses). No terminal focus needed.
#
# Usage:
#   .\scripts\dev-watch.ps1
#   .\scripts\dev-watch.ps1 -Device chrome
# ============================================================

[CmdletBinding()]
param(
    [string]$Device = "edge",
    [int]$DebounceMs = 600
)

$ErrorActionPreference = "Stop"

# --- Setup ----------------------------------------------------------------
$root        = (Get-Location).Path
$libPath     = Join-Path $root "lib"
$logDir      = Join-Path $root ".tmp"
$logFile     = Join-Path $logDir "flutter-run.log"
$errFile     = Join-Path $logDir "flutter-run.err"
New-Item -ItemType Directory $logDir -Force | Out-Null

# Load WebSocket support (built-in to .NET)
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Net.WebSockets
Add-Type -AssemblyName System.IO

# --- UI helpers ------------------------------------------------------------
function Step($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Err($m)   { Write-Host "  [X] $m" -ForegroundColor Red }
function Dim($m)   { Write-Host "      $m" -ForegroundColor DarkGray }

# --- Start flutter run -----------------------------------------------------
Step "Starting flutter run -d $Device"
"" | Out-File $logFile
"" | Out-File $errFile

$flutterProc = Start-Process -FilePath "flutter" `
    -ArgumentList "run", "-d", $Device, "--no-hot" `
    -WorkingDirectory $root `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError  $errFile `
    -PassThru

# Display the flutter log as it grows (tail -f style)
$tail = Start-Job -ScriptBlock {
    param($file)
    $last = 0
    while ($true) {
        if (Test-Path $file) {
            $len = (Get-Item $file).Length
            if ($len -gt $last) {
                $reader = [System.IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
                $reader.Position = $last
                $stream = New-Object System.IO.StreamReader($reader)
                $text = $stream.ReadToEnd()
                $stream.Close()
                $reader.Close()
                Write-Host $text -NoNewline
                $last = $len
            }
        }
        Start-Sleep -Milliseconds 250
    }
} -ArgumentList $logFile

# --- Find VM service URL ---------------------------------------------------
Step "Waiting for Dart VM service URL..."
$vmPort  = $null
$vmToken = $null
$deadline = (Get-Date).AddSeconds(180)

while ((Get-Date) -lt $deadline) {
    if ($flutterProc.HasExited) {
        Err "flutter run exited unexpectedly. Log:"
        Get-Content $errFile -Tail 30
        Stop-Job $tail; Remove-Job $tail
        exit 1
    }
    $content = ""
    if (Test-Path $logFile) { $content = Get-Content $logFile -Raw -ErrorAction SilentlyContinue }
    if ($content -match "http://127\.0\.0\.1:(\d+)/([A-Za-z0-9_\-=]+)/?") {
        $vmPort  = $matches[1]
        $vmToken = $matches[2]
        break
    }
    if ($content -match "VM service|web service is running") {
        Dim "found hint, waiting for full URL..."
    }
    Start-Sleep -Milliseconds 500
}

if (-not $vmPort) {
    Err "Timed out waiting for VM service URL. Last log lines:"
    Get-Content $logFile -Tail 20
    Stop-Process $flutterProc -Force -ErrorAction SilentlyContinue
    Stop-Job $tail; Remove-Job $tail
    exit 1
}

Ok "VM service: http://127.0.0.1:$vmPort/"

# --- Connect WebSocket -----------------------------------------------------
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$uri = [Uri]"ws://127.0.0.1:${vmPort}/${vmToken}/ws"
$ws.ConnectAsync($uri, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
Ok "WebSocket connected"

# --- Helper: send a VM service RPC ----------------------------------------
function Send-VMCommand {
    param([string]$Method)
    $payload = '{"jsonrpc":"2.0","method":"' + $Method + '","id":1}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $seg = New-Object System.ArraySegment[byte] (, $bytes)
    try {
        $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true,
            [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
        return $true
    } catch {
        Warn "Send failed: $_"
        return $false
    }
}

# Keep-alive: read incoming WS messages so the connection stays open
$null = Register-ObjectEvent -InputObject $ws -EventName MessageReceived `
    -SourceIdentifier "wsMessage" -Action { } -ErrorAction SilentlyContinue

# --- File watcher + debounced hot-restart ----------------------------------
Step "Watching $libPath for *.dart changes"
Ok "Save any file = hot restart fires automatically (debounce ${DebounceMs}ms)"
Dim "Press Ctrl+C to stop."

# Timer for debounce
$timer = New-Object System.Timers.Timer
$timer.Interval = $DebounceMs
$timer.AutoReset = $false
$timer.add_Elapsed({
    $ts = (Get-Date).Format("HH:mm:ss")
    Write-Host ""
    Write-Host "[$ts] hot restart..." -ForegroundColor Magenta
    # Hot restart = full app restart (state reset, full compile)
    # For web this equals a full page reload
    Send-VMCommand -Method "_flutter.hotRestart"
})

# File system watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $libPath
$watcher.IncludeSubdirectories = $true
$watcher.Filter = "*.dart"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor `
                       [System.IO.NotifyFilters]::LastWrite -bor `
                       [System.IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents = $true

$action = {
    $ts = (Get-Date).Format("HH:mm:ss")
    Write-Host "[$ts] change: $($Event.SourceEventArgs.Name)" -ForegroundColor Yellow
    $timer.Stop()
    $timer.Start()
}

$handlers = @()
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Changed  -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action

# --- Keep alive until user Ctrl+C ------------------------------------------
try {
    while ($true) {
        Start-Sleep -Seconds 5
        if ($flutterProc.HasExited) {
            Err "flutter run process died. Tail of log:"
            Get-Content $errFile -Tail 20
            break
        }
    }
} finally {
    Step "Shutting down"
    $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name -ErrorAction SilentlyContinue }
    $watcher.Dispose()
    $timer.Dispose()
    try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done",
        [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() } catch {}
    if (-not $flutterProc.HasExited) { Stop-Process $flutterProc -Force -ErrorAction SilentlyContinue }
    Stop-Job $tail -ErrorAction SilentlyContinue; Remove-Job $tail -ErrorAction SilentlyContinue
    Ok "Bye"
}
