# AI思政打卡APP — 南华大学计算机学院

## 项目概述

集**查寝打卡、上课打卡、实习打卡**于一体的"AI思政"辅助APP，以数字化手段提升学生管理效率。

## 技术栈

| 层 | 技术 |
|---|------|
| 移动端 | Flutter 3.24+ |
| 管理Web端 | React 18 + Ant Design 5 |
| 数据大屏 | Vue 3 + ECharts |
| 后端 | Spring Boot 3.3 / Java 17 |
| 数据库 | SQL Server 2019+ |
| 缓存 | Redis 7 |
| 对象存储 | MinIO |
| AI能力 | 百度AI人脸识别 + 活体检测 |

## 项目结构

```
C:\1234\
├── PRD_AI思政打卡APP_产品需求文档.md    # 产品需求文档
├── TRD_AI思政打卡APP_技术需求文档.md    # 技术需求文档
├── backend/                             # Spring Boot 后端
│   ├── pom.xml
│   └── src/main/java/com/nhu/aisizheng/
│       ├── AiSizhengApplication.java    # 启动入口
│       ├── common/                      # 通用类 (Result, GlobalExceptionHandler)
│       ├── config/                      # 配置类 (Security, Redis, CORS)
│       ├── controller/                  # 控制器 (Auth, Checkin, Health)
│       ├── model/                       # 实体类 (User, CheckinRecord, CheckinSite)
│       ├── repository/                  # 数据访问层 (JPA Repository)
│       ├── service/                     # 业务逻辑层 (AuthService, CheckinService)
│       └── utils/                       # 工具类 (JwtUtils, GeoUtils)
├── infrastructure/                      # 基础设施配置
│   ├── docker-compose.yml               # Redis + MinIO
│   └── init_db.sql                      # SQL Server 建表脚本
├── mobile/                              # Flutter 移动端 (待创建)
└── admin-web/                           # React 管理后台 (待创建)
```

## 快速启动

### 0. 前置条件
- JDK 17 + Maven 3.9+
- SQL Server (本机实例 localhost)
- Docker Desktop (Redis + MinIO)
- Flutter SDK 3.24+
- Node.js 20+

### 1. 初始化数据库

```bash
# 已在运行: sqlcmd -S localhost -E -Q "CREATE DATABASE ai_sizheng"
# 建表:
sqlcmd -S localhost -E -d ai_sizheng -i infrastructure/init_db.sql
```

### 2. 启动基础设施

```bash
cd infrastructure
docker-compose up -d
# 启动 Redis (6379) + MinIO (9000/9001)
# MinIO Console: http://localhost:9001 (admin/admin123456)
```

### 3. 启动后端

```bash
cd backend
mvn spring-boot:run
# API地址: http://localhost:8080
# Knife4j文档: http://localhost:8080/doc.html
```

### 4. 启动管理Web端

```bash
cd admin-web
npm install
npm run dev
# 地址: http://localhost:5173
```

### 5. 启动移动端

```bash
cd mobile
flutter pub get
flutter run
```

## 当前环境状态 (2026-06-26)

| 组件 | 状态 | 备注 |
|------|------|------|
| ✅ Java 17 (Temurin) | 已安装 | OpenJDK 17.0.18 |
| ✅ Maven 3.9.14 | 已安装 | |
| ✅ Node.js 24.14 | 已安装 | |
| ✅ Git 2.54 | 已安装 | |
| ✅ SQL Server 2025 | 运行中 | localhost, Windows Auth |
| ✅ ai_sizheng 数据库 | 已创建 | 7张表 |
| ✅ Spring Boot 项目 | 已创建 | pom.xml + 核心Java文件 |
| ⚠️ Docker Desktop | 已安装未启动 | Redis/MinIO 需Docker |
| ⚠️ Flutter SDK | 下载中 | ~1GB, 网络较慢需重试 |
| ❌ 百度AI Key | 未注册 | 需前往 console.bce.baidu.com |

## 待完成

1. **Docker启动**: 启动Docker Desktop后运行 `docker-compose up -d`
2. **Flutter安装**: 手动下载 https://docs.flutter.dev/get-started/install/windows
3. **百度AI注册**: https://console.bce.baidu.com → 创建应用 → 获取API Key
4. **Maven下载依赖**: `cd backend && mvn dependency:resolve`
5. **前端项目创建**: React管理端 + Vue大屏
