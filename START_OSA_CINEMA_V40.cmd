@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>&1
if errorlevel 1 (
  echo OSA CINEMA V40 requires Node.js 22 or newer.
  exit /b 1
)
node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)"
if errorlevel 1 (
  echo OSA CINEMA V40 requires Node.js 22 or newer.
  exit /b 1
)
if not exist "%~dp0scripts\osa-cinema-v40-audit-worker.mjs" (
  echo Missing V40 isolated audit worker. Refusing partial installation.
  exit /b 1
)
call "%~dp0START_OSA_CINEMA_V39.cmd"
exit /b %errorlevel%
