# OSA CINEMA V39: private local interactive Windows launch. No passwords on argv/disk.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nodePath = (Get-Command node -ErrorAction Stop).Source
$code = Join-Path $repoRoot 'scripts\osa-cinema-v39-owner-desk.mjs'
Write-Host 'OSA CINEMA V39 / Private local owner desk / PUBLIC FILM NO-GO'
Write-Host 'Choose existing PRIVATE folders outside the code repository.'
$receipts = Read-Host 'Full path to V29 report folder (CHECKSUMS.sha256)'
$masters = Read-Host 'Full path to folder with 4 final MP4'
$captions = Read-Host 'Full path to folder with 4 WebVTT'
$secret = Read-Host 'Private owner password (minimum 16 characters)' -AsSecureString
$pointer = [IntPtr]::Zero
try {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
  $env:OSA_CINEMA_OWNER_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  if ($env:OSA_CINEMA_OWNER_PASSWORD.Length -lt 16) { throw 'Private password too short.' }
  & $nodePath $code --repo-root $repoRoot --receipts-dir $receipts --masters-dir $masters --captions-dir $captions
  exit $LASTEXITCODE
}
finally {
  Remove-Item Env:OSA_CINEMA_OWNER_PASSWORD -ErrorAction SilentlyContinue
  if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
