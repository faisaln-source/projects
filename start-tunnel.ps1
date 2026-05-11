# Wavify - Cloudflare Quick Tunnel Launcher

$ApiDir       = "$PSScriptRoot\MusicApp.Api"
$UiDir        = "$PSScriptRoot\music-app-ui"
$FrontendPort = 4200

Write-Host ""
Write-Host "  Wavify - Cloudflare Tunnel Launcher" -ForegroundColor Cyan
Write-Host ""

# 1. Start cloudflare quick tunnel in background
Write-Host "[1/5] Starting Cloudflare quick tunnel on port $FrontendPort..." -ForegroundColor Yellow
$logFile = "$env:TEMP\cloudflared-wavify.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

$cfProc = Start-Process -FilePath "cloudflared" `
              -ArgumentList "tunnel --url http://localhost:$FrontendPort" `
              -RedirectStandardError $logFile `
              -NoNewWindow -PassThru

# 2. Wait for tunnel URL
Write-Host "[2/5] Waiting for tunnel URL (up to 60s)..." -ForegroundColor Yellow
$tunnelUrl = $null
$attempts  = 0
while (-not $tunnelUrl -and $attempts -lt 30) {
    Start-Sleep -Seconds 2
    $attempts++
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        $match   = [regex]::Match($content, 'https://[a-z0-9\-]+\.trycloudflare\.com')
        if ($match.Success) { $tunnelUrl = $match.Value }
    }
}

if (-not $tunnelUrl) {
    Write-Host "ERROR: Could not detect tunnel URL after 60s." -ForegroundColor Red
    Stop-Process -Id $cfProc.Id -Force
    exit 1
}

$tunnelHost = $tunnelUrl -replace 'https://', ''
Write-Host ""
Write-Host "  Tunnel URL: $tunnelUrl" -ForegroundColor Green
Write-Host ""

# 3. Patch appsettings.Local.json
Write-Host "[3/5] Patching appsettings.Local.json..." -ForegroundColor Yellow
$settingsPath = "$ApiDir\appsettings.Local.json"
$settings = Get-Content $settingsPath -Raw
$settings = $settings -replace '"RedirectUri":\s*"https://[^"]*"', ('"RedirectUri": "' + $tunnelUrl + '/auth/callback"')
Set-Content $settingsPath $settings -Encoding UTF8
Write-Host "      RedirectUri = $tunnelUrl/auth/callback" -ForegroundColor Green

# 4. Patch Program.cs
Write-Host "[4/5] Patching Program.cs CORS..." -ForegroundColor Yellow
$programPath = "$ApiDir\Program.cs"
$program = Get-Content $programPath -Raw
$program = $program -replace '"https://[a-z0-9\-]+\.(ngrok-free\.dev|trycloudflare\.com)"', ('"' + $tunnelUrl + '"')
Set-Content $programPath $program -Encoding UTF8
Write-Host "      CORS origin = $tunnelUrl" -ForegroundColor Green

# 5. Patch angular.json
Write-Host "[5/5] Patching angular.json allowedHosts..." -ForegroundColor Yellow
$angularPath = "$UiDir\angular.json"
$angular = Get-Content $angularPath -Raw
$angular = $angular -replace '"[a-z0-9\-]+\.(ngrok-free\.dev|trycloudflare\.com)"', ('"' + $tunnelHost + '"')
Set-Content $angularPath $angular -Encoding UTF8
Write-Host "      allowedHosts = $tunnelHost" -ForegroundColor Green

# 6. Restart ng serve with --allowed-hosts
Write-Host ""
Write-Host "Restarting ng serve with --allowed-hosts..." -ForegroundColor Yellow

# Kill any existing ng serve process
Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -eq "" -and ($_.CommandLine -like "*ng*serve*" -or $_.Path -like "*node*")
} | Stop-Process -Force -ErrorAction SilentlyContinue

# Also kill by port 4200
$portPid = (Get-NetTCPConnection -LocalPort 4200 -ErrorAction SilentlyContinue).OwningProcess | Select-Object -First 1
if ($portPid) {
    Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue
    Write-Host "      Stopped process on port 4200 (PID $portPid)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}

# Start ng serve with allowed-hosts flag
$ngServeLog = "$env:TEMP\ng-serve-wavify.log"
Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c ng serve --allowed-hosts $tunnelHost > `"$ngServeLog`" 2>&1" `
    -WorkingDirectory $UiDir `
    -NoNewWindow
Write-Host "      ng serve restarted with --allowed-hosts $tunnelHost" -ForegroundColor Green

# Copy to clipboard
$tunnelUrl | Set-Clipboard

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  ACTION REQUIRED: Update Spotify Dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Go to: https://developer.spotify.com/dashboard" -ForegroundColor White
Write-Host "  2. Your App -> Edit Settings -> Redirect URIs" -ForegroundColor White
Write-Host "  3. Add or replace with:" -ForegroundColor White
Write-Host "     $tunnelUrl/auth/callback" -ForegroundColor Cyan
Write-Host "  4. Save" -ForegroundColor White
Write-Host ""
Write-Host "  Tunnel URL copied to clipboard!" -ForegroundColor Magenta
Write-Host "  Open your app at: $tunnelUrl" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Press Ctrl+C to stop the tunnel." -ForegroundColor DarkGray
Write-Host ""

# Keep alive
Wait-Process -Id $cfProc.Id
