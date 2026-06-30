@echo off
setlocal

if not exist "%~dp0.env.tencent.local" (
  echo Missing .env.tencent.local. Create it from .env.tencent.example.
  exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~dp0.env.tencent.local") do (
  if not "%%A"=="" set "%%A=%%B"
)

echo [1/2] Applying database migrations...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0infrastructure\run-migrations.ps1" -Server localhost -Database ai_sizheng
if errorlevel 1 exit /b %errorlevel%

echo [2/2] Starting backend...
cd /d "%~dp0backend"
"C:\Maven\apache-maven-3.9.14\bin\mvn.cmd" spring-boot:run
