# OSA CINEMA V31 - localhost only. Does NOT publish films or accept legal approvals automatically.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo
foreach ($tool in @('node', 'ffmpeg', 'ffprobe')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Missing dependency: $tool. Install Node.js 22 and FFmpeg first."
  }
}
$root = Read-Host 'Absolute path to private film folder (masters + captions)'
$reports = Read-Host 'Absolute path to separate private reports folder'
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'Film folder does not exist.' }
if (-not (Test-Path -LiteralPath $reports -PathType Container)) { throw 'Reports folder does not exist.' }
$secure = Read-Host 'New owner-only console password (16+ characters)' -AsSecureString
$env:OSA_CINEMA_OWNER_CONSOLE_PASSWORD = [System.Net.NetworkCredential]::new('', $secure).Password
try {
  Write-Host 'Starting PRIVATE owner console on 127.0.0.1. No public upload.'
  Write-Host 'Open the exact URL printed by Node in a browser on this computer.'
  Write-Host 'Press Ctrl+C to close the console.'
  node scripts/osa-cinema-v31-owner-console.mjs --root "$root" --reports-root "$reports" --originals docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json
  if ($LASTEXITCODE -ne 0) { throw "Owner console exited with code $LASTEXITCODE" }
}
finally {
  Remove-Item Env:\OSA_CINEMA_OWNER_CONSOLE_PASSWORD -ErrorAction SilentlyContinue
  $secure.Dispose()
}
