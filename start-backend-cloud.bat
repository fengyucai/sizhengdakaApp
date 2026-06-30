@echo off
setlocal

set "ENV_FILE=%~dp0.env.cloud.local"
if not exist "%ENV_FILE%" (
  echo Missing .env.cloud.local. Copy .env.cloud.example to .env.cloud.local and fill in cloud database values.
  exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  if not "%%A"=="" set "%%A=%%B"
)

if "%CLOUD_DB_SERVER%"=="" (
  echo CLOUD_DB_SERVER is required in .env.cloud.local.
  exit /b 1
)
if "%CLOUD_DB_DATABASE%"=="" set "CLOUD_DB_DATABASE=ai_sizheng"
if "%CLOUD_DB_USERNAME%"=="" (
  echo CLOUD_DB_USERNAME is required in .env.cloud.local.
  exit /b 1
)
if "%CLOUD_DB_PASSWORD%"=="" (
  echo CLOUD_DB_PASSWORD is required in .env.cloud.local.
  exit /b 1
)

echo [1/2] Applying cloud database migrations...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0infrastructure\run-migrations.ps1" -Server "%CLOUD_DB_SERVER%" -Database "%CLOUD_DB_DATABASE%" -Username "%CLOUD_DB_USERNAME%" -Password "%CLOUD_DB_PASSWORD%"
if errorlevel 1 exit /b %errorlevel%

echo [2/2] Starting backend with cloud database...
cd /d "%~dp0backend"
where mvn.cmd >nul 2>nul
if errorlevel 1 (
  if exist "C:\Maven\apache-maven-3.9.14\bin\mvn.cmd" (
    "C:\Maven\apache-maven-3.9.14\bin\mvn.cmd" spring-boot:run
  ) else (
    echo Maven not found. Add mvn.cmd to PATH or install Maven.
    exit /b 1
  )
) else (
  mvn.cmd spring-boot:run
)
