@echo off
chcp 65001 >nul
title OSGARD - Hardware GPU QA
color 0B
echo === OSGARD WAVE 5 / REAL HARDWARE VERIFICATION ===
echo.
echo [1] Extract a Wave 5 Windows PC Ultra .exe and .pck to same folder.
echo [2] Start the game. Press F8 for Ultra/Balanced post-processing.
echo [3] Play for 3 to 5 minutes. Press F9 for FPS/time-frame overlay.
echo [4] Press F10 to save hardware JSON in Godot user data folder.
echo [5] Repeat on an actual target GPU and compare reports.
echo.
echo No GPU performance value is certified until its measured report exists.
echo.
if exist "%APPDATA%\Godot\app_userdata" (
  explorer "%APPDATA%\Godot\app_userdata"
) else (
  echo Godot user data folder not found yet. Start the game first.
)
pause