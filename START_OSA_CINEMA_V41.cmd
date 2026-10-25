@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0scripts\osa-cinema-v41-owner-ui.mjs" (
  echo OSA CINEMA V41 UI module is missing. Installation is incomplete.
  exit /b 1
)
if not exist "%~dp0scripts\osa-cinema-v39-owner-desk.mjs" (
  echo OSA CINEMA owner desk is missing. Refusing partial installation.
  exit /b 1
)
call "%~dp0START_OSA_CINEMA_V40.cmd"
exit /b %errorlevel%
