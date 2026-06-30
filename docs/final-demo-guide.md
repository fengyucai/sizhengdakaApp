# 最终演示与回归测试指南

## 1. 演示前启动

1. 启动后端常驻窗口：

```powershell
cd C:\1234
.\start-backend-keepalive.bat
```

保持该窗口打开。健康检查地址：

```text
http://127.0.0.1:8080/actuator/health
```

2. 真机通过 USB 联调时建议开启端口反向代理：

```powershell
C:\Android\sdk\platform-tools\adb.exe reverse tcp:8080 tcp:8080
```

3. 安装最终演示 APK：

```powershell
C:\Android\sdk\platform-tools\adb.exe install -r C:\1234\mobile\build\app\outputs\flutter-apk\app-release.apk
```

## 2. 演示测试账号

基础种子数据密码统一为 `123456`。

| 角色 | 账号 | 密码 | 用途 |
| --- | --- | --- | --- |
| 学生 | `20240101` | `123456` | 学生端登录、打卡、日志、请假、申诉 |
| 教师/辅导员 | `T2024001` | `123456` | 教师移动端发起签到、审批、评阅、预警处理 |
| 管理员 | `admin` | `123456` | Web 管理端和全局数据检查 |

正式试点前应要求所有账号首次登录后修改默认密码。

## 3. 学生端回归路径

- 登录：使用学生账号登录，确认隐私授权页可同意或返回登录页。
- 人脸注册：进入人脸注册，完成正脸、微左、微右实时采集，提交后看到成功反馈。
- 查寝打卡：确认能获取定位、匹配打卡点、提交后有成功/失败提示，记录页实时刷新。
- 课堂签到：分别验证普通签到、二维码签到、位置签到、拍照签到。
- 实习打卡与日志：提交定位打卡和日志，确认提交反馈和历史记录出现。
- 请假申请：提交请假，确认申请记录实时出现，教师审批后状态刷新。
- 异常申诉：在打卡记录中提交申诉，确认教师端可看到并处理。

## 4. 教师端回归路径

- 工作台：确认学生总数、今日查寝、课堂签到、待处理预警可点击进入详情。
- 发起签到：分别发起普通签到、二维码签到、位置签到、拍照签到。
- 二维码展示：二维码签到场次可生成并刷新动态二维码，学生扫码后完成签到。
- 考勤刷新：学生签到后教师端列表和统计刷新，不出现红屏闪现。
- 审批/评阅：处理请假、实习日志、申诉后列表状态立即更新。
- 预警处理：处理待处理预警后数量变化，记录进入审计日志。
- 打卡点管理：新增/编辑时可使用定位填充经纬度和详细地址；停用点不进入位置签到选择。

## 5. 运维检查

完整试点验证：

```powershell
cd C:\1234\infrastructure
.\verify-pilot.ps1 -BaseUrl http://localhost:8080
```

健康检查：

```powershell
.\check-health.ps1 -BaseUrl http://localhost:8080 -DbServer localhost -DbPort 1433
```

备份 dry-run 或实际备份：

```powershell
.\backup-sqlserver.ps1 -Server localhost -Database ai_sizheng -BackupDir .\backups -RetentionDays 14
```

## 6. 发布包说明

当前演示 APK 路径：

```text
C:\1234\mobile\build\app\outputs\flutter-apk\app-release.apk
```

如后端地址变化，需要重新打包：

```powershell
cd C:\1234\mobile
.\tool\build-release-apk.ps1 -ApiBaseUrl http://127.0.0.1:8080 -SkipPubGet
```

正式试点发布前，应先执行 `mobile\tool\create-release-keystore.ps1` 生成正式签名配置，避免继续使用 debug fallback 签名。

## 7. 安全收尾

演示和最后一次推送结束后，处理 GitHub CLI 明文 token：

```powershell
gh auth logout -h github.com -u fengyucai
```

同时在 GitHub 网页端撤销或轮换本次使用的 PAT。
