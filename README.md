# AI思政打卡APP - 南华大学计算机学院

面向计算机学院学生管理场景的 AI 思政辅助平台，覆盖学生端打卡、辅导员管理后台和数据大屏。

## 已实现功能

- 学生端：登录、查寝打卡、上课 GPS/扫码签到、实习打卡与日志、消息中心、人脸注册、请假申请、打卡历史与异常申诉。
- 管理端：工作台、查寝管理、课堂场次与动态码、实习监控、实习日志评阅、请假审批、申诉审核、预警中心、周报 CSV 导出。
- 后端：JWT 登录鉴权、角色权限控制、电子围栏、百度 AI 真实人脸识别、百度地图逆地理编码、通知消息、自动提醒/预警定时任务。
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
| AI/地图能力 | 百度 AI 人脸识别、百度地图 Web 服务逆地理编码 |

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

后端使用 `spring.jpa.hibernate.ddl-auto=validate`，已有数据库升级时执行迁移脚本：

```powershell
cd infrastructure
.\run-migrations.ps1 -Server localhost -Database ai_sizheng
```

### 2. 基础设施

```powershell
cd infrastructure
docker-compose up -d
```

### 3. 后端

```powershell
.\start-backend-with-migrations.bat
```

默认地址：`http://localhost:8080`

接口文档：

```text
Knife4j: http://localhost:8080/doc.html
OpenAPI JSON: http://localhost:8080/v3/api-docs
Swagger UI: http://localhost:8080/swagger-ui.html
```

除登录、注册、刷新令牌、健康检查、定位解析和文档接口外，业务接口均需要在文档页面右上角 Authorize 中填写登录返回的 `accessToken`。

如果只需手动启动后端：

```powershell
cd backend
mvn spring-boot:run
```

百度 AI 与百度地图环境变量：

```powershell
$env:BAIDU_AI_APP_ID="..."
$env:BAIDU_AI_API_KEY="..."
$env:BAIDU_AI_SECRET_KEY="..."
$env:BAIDU_MAP_AK="..."
```

未配置百度 AI 时，人脸注册、活体检测和人脸打卡会直接失败，不再使用 Mock。未配置 `BAIDU_MAP_AK` 时，详细地址、省市区和周边 POI 不会生成，定位接口会明确提示缺少百度地图 AK。

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

Release APK 打包前先生成签名文件：

```powershell
cd mobile
.\tool\create-release-keystore.ps1
```

打包正式安装文件：

```powershell
.\tool\build-release-apk.ps1 -ApiBaseUrl http://服务器IP:8080
```

输出路径：

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

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
