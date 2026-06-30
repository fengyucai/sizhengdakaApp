@echo off
setlocal

if exist "%~dp0.env.tencent.local" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~dp0.env.tencent.local") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)

cd /d "%~dp0backend"
if exist "target\aisizheng-1.0.0-SNAPSHOT.jar" (
  java -jar target\aisizheng-1.0.0-SNAPSHOT.jar
) else (
  mvn.cmd spring-boot:run
)
