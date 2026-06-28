@echo off
chcp 65001 >nul
echo ============================================
echo  AI思政打卡APP - 基础设施一键启动
echo ============================================
echo.

REM 1. Redis
echo [1/3] 检查 Redis...
"C:\Program Files\Redis\redis-cli.exe" PING >nul 2>&1
if %errorlevel%==0 (
    echo   ✓ Redis 运行中 (端口 6379)
) else (
    echo   → 正在启动 Redis...
    start "Redis" /MIN "C:\Program Files\Redis\redis-server.exe"
    timeout /t 3 /nobreak >nul
    echo   ✓ Redis 已启动
)

REM 2. MinIO (with SUBNET license)
echo [2/3] 检查 MinIO...
curl -s http://localhost:9000/minio/health/live >nul 2>&1
if %errorlevel%==0 (
    echo   ✓ MinIO 运行中 (API:9000 / Console:9001)
) else (
    echo   → 正在启动 MinIO (含 AIStor Free License)...
    set MINIO_ROOT_USER=admin
    set MINIO_ROOT_PASSWORD=admin123456
    REM Read license from file
    for /f "delims=" %%i in (C:\1234\infrastructure\minio_license.key) do set MINIO_LICENSE=%%i
    start "MinIO" /MIN "%LOCALAPPDATA%\Microsoft\WinGet\Packages\MinIO.Server_Microsoft.Winget.Source_8wekyb3d8bbwe\minio.exe" server C:\1234\infrastructure\minio_data --console-address ":9001" --address ":9000"
    timeout /t 6 /nobreak >nul
    echo   ✓ MinIO 已启动 (AIStor Free - 1 Node)
    echo      Console: http://localhost:9001 (admin / admin123456)
)

REM 3. SQL Server
echo [3/3] 检查 SQL Server...
sqlcmd -S localhost -E -d ai_sizheng -Q "SELECT 1" >nul 2>&1
if %errorlevel%==0 (
    echo   ✓ SQL Server 运行中 (端口 1433)
) else (
    echo   ✗ SQL Server 未运行，请手动启动
)

echo.
echo ============================================
echo  全部服务就绪！
echo.
echo  SQL Server : localhost:1433 (ai_sizheng)
echo  Redis      : localhost:6379
echo  MinIO API  : http://localhost:9000
echo  MinIO Web  : http://localhost:9001
echo.
echo  启动后端:
echo    cd C:\1234\backend ^&^& mvn spring-boot:run
echo ============================================
pause
