@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>&1
if errorlevel 1 (
  echo OSA CINEMA V39 requires Node.js 22 or newer on PATH.
  pause
  exit /b 1
)
powershell -NoProfile -File "%~dp0scripts\osa-cinema-v39-owner-launch.ps1"
if errorlevel 1 (
  echo Private owner desk could not start. Film premiere remains NO-GO.
  pause
  exit /b 1
)
