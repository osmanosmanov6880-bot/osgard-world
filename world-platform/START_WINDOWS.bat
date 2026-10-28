@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>&1
if %errorlevel%==0 (
  set "PYTHON_CMD=py -3"
) else (
  where python >nul 2>&1
  if not %errorlevel%==0 (
    echo Python 3 is required to run the original Godot WebGL game locally.
    echo Install Python 3 from python.org, then open START_WINDOWS.bat again.
    pause
    exit /b 1
  )
  set "PYTHON_CMD=python"
)
echo.
echo  LAST FRONTIER WORLD / original Godot game
echo  REVIEW ONLY - NOT COMMERCIAL RELEASE
echo  Open: http://127.0.0.1:8765/
echo.
start "" "http://127.0.0.1:8765/"
%PYTHON_CMD% -m http.server 8765 --bind 127.0.0.1
if errorlevel 1 (
  echo.
  echo Could not open the local HTTP port 8765. Close other servers and try again.
  pause
)
endlocal
