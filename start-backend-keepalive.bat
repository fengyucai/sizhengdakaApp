@echo off
setlocal

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "RUNNER=%PROJECT_ROOT%\infrastructure\run-backend-foreground.ps1"

if not exist "%RUNNER%" (
  echo Missing backend keepalive runner: %RUNNER%
  pause
  exit /b 1
)

echo Health URL: http://127.0.0.1:8080/actuator/health
echo Keep this window open. The backend will auto-restart if it exits.

powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -Command "& '%RUNNER%' -ProjectRoot '%PROJECT_ROOT%' -Port 8080 -Profile dev"
