@echo off
setlocal

if not exist "%~dp0.env.tencent.local" (
  echo Missing .env.tencent.local. Create it from .env.tencent.example.
  exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~dp0.env.tencent.local") do (
  if not "%%A"=="" set "%%A=%%B"
)

cd /d "%~dp0backend"
"C:\Maven\apache-maven-3.9.14\bin\mvn.cmd" spring-boot:run
