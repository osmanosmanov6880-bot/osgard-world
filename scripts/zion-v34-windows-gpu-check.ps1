# ZION-030 v34: native Windows GPU acceptance
# From the repository root, run:
# powershell -NoProfile -File scripts/zion-v34-windows-gpu-check.ps1
# Requires Node.js 22+, Google Chrome and a native graphics driver.
param([int]$DurationMs = 15000,[double]$MaxP95Ms = 33.3,[switch]$Headless)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $project
if ($DurationMs -lt 8000 -or $DurationMs -gt 60000) { throw 'DurationMs outside 8000..60000' }
if ($MaxP95Ms -le 0 -or $MaxP95Ms -gt 1000) { throw 'Invalid MaxP95Ms threshold' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node 22+ first.' }
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm.cmd is required.' }
$chrome = Get-Item 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ErrorAction SilentlyContinue
if (-not $chrome) { $chrome = Get-Item 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ErrorAction SilentlyContinue }
if (-not $chrome) { throw 'Google Chrome not found.' }
$env:OSGARD_CHROME_PATH = $chrome.FullName
Write-Host 'Installing and validating authentic ZION-030 game...'
& npm.cmd ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
& npm.cmd run qa:zion-local
if ($LASTEXITCODE -ne 0) { throw 'Local ZION acceptance failed' }
& npm.cmd run build
if ($LASTEXITCODE -ne 0) { throw 'Production build failed' }
$destination = Join-Path $project 'dist/games'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -Path (Join-Path $project 'public/games/*') -Destination $destination -Recurse -Force
$vite = Join-Path $project 'node_modules/.bin/vite.cmd'
if (-not (Test-Path $vite)) { throw 'Vite preview executable missing.' }
$stdOut = Join-Path $env:TEMP 'zion-v34-preview-out.log'
$stdErr = Join-Path $env:TEMP 'zion-v34-preview-err.log'
$server = $null
try {
    # Loopback-only preview: no public test server and no saved game data upload.
    $args = '/d /s /c "' + $vite + '" preview --host 127.0.0.1 --port 4173 --strictPort'
    $server = Start-Process -FilePath 'cmd.exe' -ArgumentList $args -PassThru -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr -WindowStyle Hidden
    $url = 'http://127.0.0.1:4173/games/zion-9/queue/ZION-030/index.html'
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 700
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
    }
    if (-not $ready) { throw ('Preview failed. Logs: ' + $stdOut + ' ' + $stdErr) }
    $env:OSGARD_GPU_BENCH_URL = $url
    $env:OSGARD_BENCH_DURATION_MS = [string]$DurationMs
    $env:OSGARD_MAX_FRAME_P95_MS = $MaxP95Ms.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $env:OSGARD_REQUIRE_HARDWARE_GPU = '1'
    $env:OSGARD_HEADLESS = $(if ($Headless) { '1' } else { '0' })
    $env:OSGARD_BENCH_OUTPUT = 'reports/gpu'
    Write-Host 'Measuring real Google Chrome GPU and native OS driver...'
    & node scripts/zion-v34-hardware-benchmark.mjs
    if ($LASTEXITCODE -ne 0) { throw 'GPU benchmark failed. Check reports/gpu and console.' }
    Write-Host 'PASS native GPU + accelerated WebGL, frame p95 recorded in reports/gpu/'
}
finally {
    if ($server -and -not $server.HasExited) { & taskkill.exe /PID $server.Id /T /F 2>$null | Out-Null }
}
