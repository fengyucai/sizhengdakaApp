# AI思政打卡APP - 南华大学计算机学院

面向计算机学院学生管理场景的 AI 思政辅助平台，覆盖学生端打卡、辅导员管理后台和数据大屏。

## 已实现功能

- 学生端：登录、查寝打卡、上课 GPS/扫码签到、实习打卡与日志、消息中心、人脸注册、请假申请、打卡历史与异常申诉。
- 管理端：工作台、查寝管理、课堂场次与动态码、实习监控、实习日志评阅、请假审批、申诉审核、预警中心、周报 CSV 导出。
- 后端：JWT 登录鉴权、角色权限控制、电子围栏、百度 AI/Mock 人脸识别、通知消息、自动提醒/预警定时任务。
- 数据大屏：核心考勤指标和预警展示。

## 技术栈

| 模块 | 技术 |
| --- | --- |
| 后端 | Spring Boot 3.3, Java 17, Spring Security, JPA |
| 数据库 | SQL Server |
| 缓存/对象存储 | Redis, MinIO |
| 移动端 | Flutter |
| 管理后台 | React, Ant Design, Vite |
| 数据大屏 | Vue 3, Vite |
| AI 能力 | 百度 AI 人脸识别，未配置时自动使用 Mock |

## 项目结构

```text
C:\1234
├── backend/            # Spring Boot 后端
├── mobile/             # Flutter 学生端
├── admin-web/          # React 管理后台
├── dashboard/          # Vue 数据大屏
├── infrastructure/     # SQL 脚本、Docker Compose、启动脚本
├── PRD_AI思政打卡APP_产品需求文档.md
└── TRD_AI思政打卡APP_技术需求文档.md
```

## 快速启动

### 1. 数据库

创建 `ai_sizheng` 数据库后执行：

```powershell
sqlcmd -S localhost -E -d ai_sizheng -i infrastructure/init_db.sql
sqlcmd -S localhost -E -d ai_sizheng -i infrastructure/seed_data.sql
```

后端使用 `spring.jpa.hibernate.ddl-auto=validate`，表结构变更必须先执行 `infrastructure/init_db.sql` 中的增量 ALTER。

### 2. 基础设施

```powershell
cd infrastructure
docker-compose up -d
```

### 3. 后端

```powershell
cd backend
mvn spring-boot:run
```

默认地址：`http://localhost:8080`

百度 AI 可选环境变量：

```powershell
$env:BAIDU_AI_APP_ID="..."
$env:BAIDU_AI_API_KEY="..."
$env:BAIDU_AI_SECRET_KEY="..."
```

未配置时系统使用 `MockFaceService`，便于本地开发。

### 4. 管理后台

```powershell
cd admin-web
npm install
npm run dev
```

### 5. 数据大屏

```powershell
cd dashboard
npm install
npm run dev
```

### 6. 移动端

```powershell
cd mobile
flutter pub get
flutter run
```

当前环境中 Flutter SDK 可能未加入 PATH，因此移动端分析和运行需先安装并配置 Flutter。

## 验证命令

```powershell
cd backend
mvn.cmd test -q

cd ..\admin-web
npm.cmd run build

cd ..\dashboard
npm.cmd run build
```

## Git 提交基线

当前已按功能拆分提交，最近关键提交包括：

- `0bc864e` 管理接口角色权限控制
- `453d218` 自动提醒和未打卡预警定时任务
- `a7d22ab` 周报 CSV 导出
- `6238936` 实习日志历史与导师评阅
- `6cfaa1b` 打卡历史与异常申诉
- `b50fa06` 移动端打卡点自动选择

## 重要说明

- 管理端接口 `/manage/**` 仅允许 `ADMIN`、`INSTRUCTOR` 角色访问。
- 教师端生成课堂动态码 `/checkin/class/qr` 仅允许 `ADMIN`、`INSTRUCTOR` 角色访问。
- 查寝打卡要求学生先完成三张照片的人脸注册。
- 移动端打卡不再硬编码打卡点 ID，会根据 GPS 自动选择最近可用打卡点。
- 自动提醒/预警时间可在 `backend/src/main/resources/application-dev.yml` 的 `app.alert` 中调整。
