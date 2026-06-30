# Docker 容器化部署说明

本文档用于在本机或试点服务器上用 Docker Compose 启动 AI 思政平台的后端、教师 Web 管理端、数据大屏、Redis 和 MinIO。

## 服务端口

| 服务 | 默认地址 |
| --- | --- |
| 后端 API | http://localhost:8080 |
| 教师 Web 管理端 | http://localhost:5173 |
| 数据大屏 | http://localhost:5174 |
| MinIO API | http://localhost:9000 |
| MinIO 控制台 | http://localhost:9001 |
| Redis | localhost:6379 |

## 1. 准备环境变量

复制模板：

```powershell
Copy-Item .env.docker.example .env.docker.local
```

编辑 `.env.docker.local`，至少填写：

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `JWT_SECRET`
- `BAIDU_MAP_AK`
- 人脸服务相关 Key，按实际选择填写百度或腾讯云。

`.env.docker.local` 已被 `.gitignore` 忽略，不要提交。

## 2. 使用已有 SQL Server

如果数据库仍在宿主机或云端 SQL Server 中，保持：

```properties
DB_URL=jdbc:sqlserver://host.docker.internal:1433;databaseName=ai_sizheng;encrypt=true;trustServerCertificate=true
```

首次部署前，在数据库中执行：

```powershell
sqlcmd -S localhost -E -d ai_sizheng -i infrastructure/init_db.sql
sqlcmd -S localhost -E -d ai_sizheng -i infrastructure/seed_data.sql
```

启动：

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml up -d --build
```

## 3. 使用 Docker SQL Server

如需 SQL Server 也放入容器，先启动数据库：

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml --profile local-db up -d sqlserver
```

等待 SQL Server 完成初始化后，创建数据库并执行初始化脚本。示例：

```powershell
sqlcmd -S localhost,1433 -U sa -P "AiSizheng@2026" -Q "IF DB_ID('ai_sizheng') IS NULL CREATE DATABASE ai_sizheng"
sqlcmd -S localhost,1433 -U sa -P "AiSizheng@2026" -d ai_sizheng -i infrastructure/init_db.sql
sqlcmd -S localhost,1433 -U sa -P "AiSizheng@2026" -d ai_sizheng -i infrastructure/seed_data.sql
```

然后在 `.env.docker.local` 中设置：

```properties
DB_URL=jdbc:sqlserver://sqlserver:1433;databaseName=ai_sizheng;encrypt=true;trustServerCertificate=true
DB_USERNAME=sa
DB_PASSWORD=AiSizheng@2026
```

启动全部服务：

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml --profile local-db up -d --build
```

## 4. 查看状态

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml ps
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml logs -f backend
```

健康检查：

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

## 5. 停止与清理

停止服务：

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml down
```

停止并删除数据卷：

```powershell
docker compose --env-file .env.docker.local -f infrastructure/docker-compose.yml down -v
```

删除数据卷会清空容器内 SQL Server、Redis、MinIO 数据，仅在确认不再需要时执行。

## 6. 移动端 APK 后端地址

Docker 启动后，手机真机不能访问 `localhost:8080`，需要使用电脑局域网 IP 或服务器域名重新打包 APK：

```powershell
cd mobile
.\tool\build-release-apk.ps1 -ApiBaseUrl http://电脑局域网IP:8080
```

如果通过 USB 调试，也可以继续使用：

```powershell
adb reverse tcp:8080 tcp:8080
```

