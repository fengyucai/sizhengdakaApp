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
