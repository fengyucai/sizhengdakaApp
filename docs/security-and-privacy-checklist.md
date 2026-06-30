# 安全与隐私收尾清单

## GitHub CLI Token

为让 Codex 进程能够读取 GitHub Actions API，本机曾使用：

```powershell
gh auth login --with-token --insecure-storage -h github.com
```

这会把 token 写入当前 Windows 用户目录：

```text
C:\Users\29687\AppData\Roaming\GitHub CLI\hosts.yml
```

项目交付或演示结束后，建议执行以下任一处理：

```powershell
gh auth logout -h github.com -u fengyucai
```

或在 GitHub 网页端撤销/轮换该 PAT：

```text
GitHub -> Settings -> Developer settings -> Personal access tokens
```

保留该 token 时，应只用于本机自动化和 CI 查询，不应复制到项目文件、聊天记录、文档或截图中。

## 仓库密钥检查

提交前确认：

- 不提交 `.env`、`.env.*.local`、`android/local.properties`。
- 不提交 `*.keystore`、`*.jks`、`*.p12`。
- 不提交 APK/AAB/IPA 构建产物。
- 不提交真实百度、腾讯云、高德、极光、MinIO、SQL Server 密钥。

当前仓库使用环境变量占位：

- `BAIDU_MAP_AK`
- `BAIDU_AI_APP_ID`
- `BAIDU_AI_API_KEY`
- `BAIDU_AI_SECRET_KEY`
- `TENCENT_CLOUD_SECRET_ID`
- `TENCENT_CLOUD_SECRET_KEY`
- `TENCENT_CLOUD_APP_ID`
- `AMAP_ANDROID_KEY`
- `JPUSH_APP_KEY`
- `JPUSH_MASTER_SECRET`
- `MINIO_SECRET_KEY`
- `JWT_SECRET`

## 人脸与定位数据

试点使用时应向学生和教师说明：

- 定位数据用于查寝、课堂签到、实习签到和打卡点校准。
- 定位数据可能包含经纬度、定位精度、省市区、详细地址和时间。
- 人脸数据用于首次录入、拍照签到核验和防代签。
- 人脸识别通过已配置的服务提供商完成，不应在客户端或日志中长期保存原始照片。
- 教师只能查看授权班级范围内的数据；管理员用于系统维护和全局配置。

## 数据保留周期建议

| 数据类型 | 用途 | 建议保留周期 |
| --- | --- | --- |
| 账号基础信息 | 身份识别、班级管理、权限控制 | 在校/在岗期间长期保留，离校后按学校制度归档或删除 |
| 人脸原始图片 | 首次录入、拍照签到临时核验 | 原始图片仅短期保留，建议 7 天内清理；正式试点优先保留不可逆特征或服务商人脸库记录 |
| 人脸特征/人脸库 ID | 人脸注册与签到比对 | 在校期间保留，学生离校或撤回授权后删除 |
| 定位记录 | 查寝、课堂、实习签到核验和申诉处理 | 建议保留 1 个学期至 1 学年，超过期限脱敏归档 |
| 打卡记录 | 考勤统计、预警、申诉依据 | 建议保留 1 个学年至毕业归档期 |
| 请假与申诉记录 | 审批留痕、争议复核 | 建议保留 1 个学年至毕业归档期 |
| 实习日志与评阅 | 实习过程管理、校企协同育人 | 建议保留至实习结束后 1 学年 |
| 通知与预警 | 消息送达、异常跟进 | 建议保留 180 天至 1 学年 |
| 审计日志 | 追踪教师端关键操作和安全事件 | 建议至少保留 1 年 |
| 后端运行日志 | 故障排查和安全审计 | 普通日志 14 天，错误日志 30 天；涉及安全事件时单独归档 |

## 运行日志

后端日志位置：

```text
backend\logs\ai-sizheng.log
backend\logs\ai-sizheng-error.log
```

日志用于排查启动、接口、签到和第三方服务异常。正式试点时不应记录完整人脸图片、明文密码、第三方密钥或完整 token。

## 发布前安全检查命令

```powershell
cd C:\1234
rg -n "ghp_|github_pat_|AKID|SecretKey|SDK_KEY|oauth_token|password\s*=|secret-key|api-key|master-secret" . `
  -S -g "!**/build/**" -g "!**/target/**" -g "!**/node_modules/**" -g "!**/.git/**"
git status --short
```

命中项应为示例占位、环境变量名或测试配置；真实密钥必须移出仓库并轮换。
