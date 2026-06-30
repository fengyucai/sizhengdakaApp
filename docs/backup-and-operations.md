# 备份、恢复与运行监控

## SQL Server 备份

试点期建议每天至少执行一次完整备份，保留 14 天；正式运行可按“每日全量 + 关键节点手动备份”的方式执行。

```powershell
cd C:\1234\infrastructure
.\backup-sqlserver.ps1 -Server localhost -Database ai_sizheng -BackupDir .\backups -RetentionDays 14
```

使用 SQL 账号时：

```powershell
.\backup-sqlserver.ps1 -Server "db.example.com,1433" -Database ai_sizheng -Username "db_user" -Password "db_password"
```

备份文件命名规则：

```text
ai_sizheng_yyyyMMdd_HHmmss.bak
```

## 数据库恢复

恢复是高风险操作，脚本默认只做 dry-run。确认备份文件正确后再加 `-Force`。

```powershell
cd C:\1234\infrastructure
.\restore-sqlserver.ps1 -Server localhost -Database ai_sizheng -BackupFile .\backups\ai_sizheng_20260630_180000.bak -Force
```

恢复前建议：

- 停止后端服务，避免写入冲突。
- 复制一份 `.bak` 到独立目录留存。
- 恢复后执行健康检查和核心登录/签到流程。

## 试点数据导出

用于阶段汇报或迁移前留档，导出核心表 CSV：

```powershell
cd C:\1234\infrastructure
.\export-trial-data.ps1 -Server localhost -Database ai_sizheng -ExportDir .\trial-export
```

导出表包括：`sys_user`、`checkin_site`、`class_session`、`checkin_record`、`leave_request`、`intern_log`、`notification`、`audit_log`。

## 健康检查

```powershell
cd C:\1234\infrastructure
.\check-health.ps1 -BaseUrl http://localhost:8080
```

如需同时检查数据库 TCP 连通：

```powershell
.\check-health.ps1 -BaseUrl http://localhost:8080 -DbServer localhost -DbPort 1433
```

## 日志策略

后端已配置 Logback 滚动日志：

- 普通日志：`backend\logs\ai-sizheng.log`
- 错误日志：`backend\logs\ai-sizheng-error.log`
- 普通日志保留 14 天，单文件 20MB。
- 错误日志保留 30 天，单文件 20MB。

可通过环境变量调整：

```powershell
$env:LOG_PATH="D:\ai-sizheng-logs"
$env:APP_LOG_LEVEL="INFO"
$env:SECURITY_LOG_LEVEL="INFO"
```

## 后台推送路径

当前已实现前台/活跃 APP 的 SSE 实时通知；后台推送保留配置路径，默认不启用收费或厂商 SDK：

```env
PUSH_PROVIDER=NONE
JPUSH_APP_KEY=
JPUSH_MASTER_SECRET=
JPUSH_PRODUCTION=false
```

后续如接极光或厂商推送，需要补齐：

- 后端 `MobilePushService` 中对应 provider 的 SDK 调用。
- Flutter 端厂商推送 SDK 初始化、设备 token 上报接口。
- 隐私政策和消息通知权限说明。
- Android 厂商通道配置和包名/签名校验。
