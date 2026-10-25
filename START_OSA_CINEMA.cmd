@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo OSA CINEMA: Node.js 22+ is not installed or not in PATH.
  echo Install Node.js 22 and FFmpeg, then retry.
  pause
  exit /b 1
)
node scripts\osa-cinema-v32-package-integrity.mjs "%~dp0"
if errorlevel 1 (
  echo.
  echo STOP: The OSA CINEMA package did not match its SHA256 manifest.
  echo Do not launch or publish anything. Download a clean package.
  pause
  exit /b 1
)
node scripts\osa-cinema-v32-first-run.mjs
set result=%errorlevel%
if not "%result%"=="0" (
  echo.
  echo OSA CINEMA: Some preparation or verification steps remain.
  pause
)
exit /b %result%
