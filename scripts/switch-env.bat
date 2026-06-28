@echo off
REM Switch between environment configurations
REM Usage: scripts\switch-env.bat [staging|production]
REM NOTE: 'local' option removed — use staging for development.

set ENV=%1
if "%ENV%"=="" set ENV=staging

if "%ENV%"=="staging" goto copy
if "%ENV%"=="production" goto copy

echo Usage: scripts\switch-env.bat [staging^|production]
echo.
echo   staging    - Staging cloud Supabase (development)
echo   production - Production cloud Supabase (live)
exit /b 1

:copy
if not exist ".env.%ENV%" (
    echo Error: .env.%ENV% not found
    exit /b 1
)
copy /Y ".env.%ENV%" ".env" >nul
if not exist "assets" mkdir "assets"
copy /Y ".env.%ENV%" "assets\.env" >nul
echo Switched to %ENV% environment
