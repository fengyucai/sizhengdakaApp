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
