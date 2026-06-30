# 云端 SQL Server 最小改动部署

本项目的最小云端存储方案是：移动端和教师端继续访问后端 API，后端通过环境变量连接云端 SQL Server。APP 不直接连接数据库，数据库账号和密码不写入 APK。

## 1. 准备云数据库

在腾讯云、阿里云、华为云等平台创建 SQL Server 实例，建议：

- 数据库名：`ai_sizheng`
- 专用账号：只授权访问 `ai_sizheng`
- 网络白名单：只放行后端服务器公网 IP 或固定出口 IP
- 开启自动备份

## 2. 创建本地私有环境文件

复制根目录模板：

```powershell
Copy-Item .env.cloud.example .env.cloud.local
```

填写 `.env.cloud.local`：

```text
CLOUD_DB_SERVER=云数据库地址,1433
CLOUD_DB_DATABASE=ai_sizheng
CLOUD_DB_USERNAME=数据库账号
CLOUD_DB_PASSWORD=数据库密码

DB_URL=jdbc:sqlserver://云数据库地址:1433;databaseName=ai_sizheng;encrypt=true;trustServerCertificate=true
DB_USERNAME=数据库账号
DB_PASSWORD=数据库密码
JWT_SECRET=至少32位随机字符串
```

`.env.cloud.local` 已被 `.gitignore` 忽略，不要提交。

## 3. 初始化云数据库

首次部署执行：

```powershell
cd C:\1234\infrastructure
.\init-cloud-database.ps1 `
  -Server "云数据库地址,1433" `
  -Database "ai_sizheng" `
  -Username "数据库账号" `
  -Password "数据库密码"
```

如需导入演示账号和打卡点，追加 `-Seed`。注意：`seed_data.sql` 会清理并重建演示数据，不要对正式库随意执行。

## 4. 启动云数据库后端

```powershell
cd C:\1234
.\start-backend-cloud.bat
```

脚本会读取 `.env.cloud.local`，先执行迁移，再启动后端。

## 5. 重新打包 APP

后端部署到云服务器并获得公网地址或 HTTPS 域名后，重新打包：

```powershell
cd C:\1234\mobile
.\tool\build-release-apk.ps1 -ApiBaseUrl https://你的后端域名
```

正式试点建议使用 HTTPS 域名，不建议长期使用公网 IP + HTTP。

## 6. 数据存储边界

- 云 SQL Server：账号、班级、打卡点、打卡记录、请假、日志、审批、通知、审计日志。
- 对象存储：人脸图片、请假附件、日志附件等文件。
- 手机本地：登录 token、少量页面缓存。

后续如果要把 MinIO 也迁到云端，可以优先选择腾讯云 COS、阿里云 OSS 或云服务器上的 MinIO，并只在环境变量中替换对象存储配置。
