@echo off
set ANDROID_HOME=C:\Android\sdk
set ANDROID_SDK_ROOT=C:\Android\sdk
set PATH=C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows;C:\Program Files\Git\cmd;%PATH%

echo Building Flutter APK...
cd /d C:\1234\mobile_build
C:\flutter\bin\flutter.bat build apk --debug

if %ERRORLEVEL% EQU 0 (
  echo.
  echo ==========================================
  echo   APK BUILD SUCCESS!
  echo   Output: build\app\outputs\flutter-apk\
  echo ==========================================
  dir build\app\outputs\flutter-apk\*.apk
) else (
  echo APK build failed with error code %ERRORLEVEL%
)
pause
