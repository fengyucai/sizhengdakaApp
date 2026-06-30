# AI思政移动端

Flutter 学生端应用，支持查寝打卡、课堂签到、实习打卡、人脸采集、请假、消息和打卡记录申诉。

## 环境

- Flutter SDK: `C:\flutter`
- Android SDK: `C:\Android\sdk`
- JDK: `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot`

## 本地运行

Android 模拟器访问宿主机后端时使用 `10.0.2.2`：

```powershell
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080
```

真机调试时，将 `API_BASE_URL` 改成电脑在同一局域网中的 IP：

```powershell
flutter run --dart-define API_BASE_URL=http://电脑IP:8080
```

## Release APK

首次正式打包前生成 Android 签名文件：

```powershell
.\tool\create-release-keystore.ps1
```

打包 release APK：

```powershell
.\tool\build-release-apk.ps1 -ApiBaseUrl http://服务器IP:8080
```

输出文件位于：

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 代码检查

在 Codex 受限环境或 Flutter 全局缓存锁异常时，`flutter analyze` 可能卡在
`C:\flutter\bin\cache\lockfile`。项目代码本身可以直接使用 Dart analyzer 快速检查：

```powershell
.\tool\analyze-fast.ps1
```

如果需要完整调用 Flutter 官方分析流程，可使用带陈旧锁清理的脚本：

```powershell
.\tool\flutter-analyze-safe.ps1 -NoPub
```

若提示缺少 `.dart_tool\package_config.json`，先在普通 PowerShell 中运行一次：

```powershell
flutter pub get
```
