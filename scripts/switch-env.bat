@echo off
REM Switch between environment configurations
REM Usage: scripts\switch-env.bat [local|staging|production]

set ENV=%1
if "%ENV%"=="" set ENV=local

if "%ENV%"=="local" goto copy
if "%ENV%"=="staging" goto copy
if "%ENV%"=="production" goto copy

echo Usage: scripts\switch-env.bat [local^|staging^|production]
echo.
echo   local      - Local Supabase (http://127.0.0.1:54321)
echo   staging    - Staging cloud Supabase
echo   production - Production cloud Supabase
exit /b 1

:copy
if not exist ".env.%ENV%" (
    echo Error: .env.%ENV% not found
    exit /b 1
)
copy /Y ".env.%ENV%" ".env" >nul
echo Switched to %ENV% environment
