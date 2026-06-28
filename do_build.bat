@echo off
set ANDROID_HOME=C:\Android\sdk
set ANDROID_SDK_ROOT=C:\Android\sdk
set PATH=C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;C:\Program Files\Git\mingw64\bin;%PATH%
cd /d C:\1234\mobile_build
echo ANDROID_HOME=%ANDROID_HOME%
echo Building APK...
C:\flutter\bin\flutter.bat build apk --debug
echo Exit code: %ERRORLEVEL%
dir /s build\*.apk 2>nul
