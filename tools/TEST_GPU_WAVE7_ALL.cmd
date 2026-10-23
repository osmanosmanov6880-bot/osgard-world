@echo off
chcp 65001 >nul
setlocal EnableExtensions
set "ROOT=%~dp0"
echo ==========================================================
echo OSGARD WORLD WAVE 7 - REAL WINDOWS GPU PERFORMANCE TEST
echo ==========================================================
echo This runs native Godot Forward+ builds on this PC.
echo Do not use remote desktop / virtual GPU for hardware sign-off.
echo Requires BOTH game .exe and matching .pck files in this folder.
echo Tests eight 30-second profiles at 1080p and 1440p.
echo.
if not exist "%ROOT%TEST_GPU_WINDOWS_RU.cmd" goto :Missing
if not exist "%ROOT%CERTIFY_GPU_WAVE7.ps1" goto :Missing
call "%ROOT%TEST_GPU_WINDOWS_RU.cmd"
if errorlevel 1 (
 echo Hardware benchmark stopped with an error.
 exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%CERTIFY_GPU_WAVE7.ps1" -ReportDirectory "%ROOT%GPU_REPORTS_WAVE6"
exit /b %errorlevel%
:Missing
echo Missing benchmark components. Extract the complete OSGARD Wave 7 Windows ZIP.
exit /b 2
