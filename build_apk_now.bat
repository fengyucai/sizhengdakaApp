@echo off
setlocal
set ANDROID_HOME=C:\Android\sdk
set ANDROID_SDK_ROOT=C:\Android\sdk
set PATH=C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;C:\Program Files\Git\mingw64\bin;%PATH%

echo =====================================
echo  AI思政 - Flutter APK Build
echo =====================================
echo ANDROID_HOME=%ANDROID_HOME%
echo.

where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: git not found in PATH
  exit /b 1
)
echo Git: OK

C:\flutter\bin\flutter.bat config --android-sdk C:\Android\sdk
echo.

cd /d C:\1234\mobile_build
echo Cleaning previous builds...
rmdir /s /q build 2>nul

echo.
echo Building debug APK...
echo This will take 3-5 minutes on first build...
echo.
C:\flutter\bin\flutter.bat build apk --debug 2>&1

if %ERRORLEVEL% EQU 0 (
  echo.
  echo =====================================
  echo   BUILD SUCCESS!
  echo =====================================
  dir /s build\*.apk
) else (
  echo.
  echo =====================================
  echo   BUILD FAILED (Error: %ERRORLEVEL%)
  echo =====================================
)
