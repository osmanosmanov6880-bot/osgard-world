@echo off
chcp 65001 >nul
setlocal EnableExtensions
set "ROOT=%~dp0"
set "REPORTS=%ROOT%GPU_REPORTS_WAVE6"
if not exist "%REPORTS%" mkdir "%REPORTS%"
echo.
echo OSGARD WORLD - WAVE 6 REAL GPU BENCHMARK
echo The test is run on YOUR Windows GPU. VSync disabled during sampling.
echo GPU, driver, FPS, frame times and draw calls saved to JSON.
echo.
if not exist "%ROOT%VECTOR_ZERO_BLACKFIELD_PC_ULTRA.exe" (
 echo Missing VECTOR_ZERO_BLACKFIELD_PC_ULTRA.exe
 goto :FAILED
)
if not exist "%ROOT%OSGARD_CHRONOS_CITY_PC_ULTRA.exe" (
 echo Missing OSGARD_CHRONOS_CITY_PC_ULTRA.exe
 goto :FAILED
)
for %%R in (1080 1440) do (
 if "%%R"=="1080" (set "RESOLUTION=1920x1080") else (set "RESOLUTION=2560x1440")
 call :TESTRES %%R
 if errorlevel 1 goto :FAILED
)
echo.
echo Benchmark finished. Reports: %REPORTS%
echo Run F9 in game to display live FPS; F10 saves an additional device report.
pause
exit /b 0

:TESTRES
if "%~1"=="1080" (set "RESOLUTION=1920x1080") else (set "RESOLUTION=2560x1440")
for %%Q in (ultra balanced) do (
 echo VECTOR ZERO %RESOLUTION% %%Q
 "%ROOT%VECTOR_ZERO_BLACKFIELD_PC_ULTRA.exe" -- --w6-benchmark --w6-duration=30 --w6-warmup=7 "--w6-resolution=%RESOLUTION%" "--w6-profile=%%Q" "--w6-output=%REPORTS%\vector_%~1_%%Q.json"
 if errorlevel 1 exit /b 1
 echo CHRONOS CITY %RESOLUTION% %%Q
 "%ROOT%OSGARD_CHRONOS_CITY_PC_ULTRA.exe" -- --w6-benchmark --w6-duration=30 --w6-warmup=7 "--w6-resolution=%RESOLUTION%" "--w6-profile=%%Q" "--w6-output=%REPORTS%\chronos_%~1_%%Q.json"
 if errorlevel 1 exit /b 1
)
exit /b 0

:FAILED
echo Benchmark stopped. Please verify the game files and your graphics driver.
pause
exit /b 1