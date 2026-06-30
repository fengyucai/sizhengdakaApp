# 原生定位与动态活体 SDK 接入计划

## 当前状态

- 定位：已接入高德 Android 定位 SDK 原生通道，优先返回经纬度、精度、定位类型、省、市、区、街道、详细地址和时间戳；失败时回退到系统融合定位，后端可继续通过地图服务补全地址。
- 人脸：App 端使用实时摄像头与 Google ML Kit 做正脸、左转、右转等动作采集校验，后端使用腾讯云人脸库做人脸注册、搜索和比对。

## 定位服务候选

### 高德定位 SDK

适合国内 Android 场景，支持 GPS、网络、Wi-Fi、基站等融合定位。接入需要：

- 高德开放平台 Android Key。
- Android 定位 SDK 依赖或 AAR。
- `AndroidManifest.xml` 中配置高德 Key、定位 service 和必要权限。
- Flutter `MethodChannel` 封装原生定位结果，字段至少包含：经纬度、精度、定位类型、省、市、区、街道、详细地址、时间戳。

### 腾讯定位 SDK（备用候选）

同样适合国内 Android 场景，可作为高德的替代供应商。当前项目未接入腾讯定位 SDK，避免同时维护多套定位原生依赖。若后续确有高德不可用场景，再新增独立定位 provider。接入需要：

- 腾讯位置服务 Key。
- Android 定位 SDK 依赖或 AAR。
- `AndroidManifest.xml` 中配置腾讯 Key、定位 service 和必要权限。
- Flutter `MethodChannel` 封装原生定位结果。

## 推荐定位架构

1. App 设置中保留“快速定位”开关。
2. 当前默认优先使用 `amap` 原生定位。
3. 高德 Key 或原生 SDK 不可用时回退到系统融合定位。
4. 后续如接入腾讯定位，应新增独立 provider，不要混入现有高德通道。

## ArcSoft 动态活体接入（已废弃验证路线）

ArcSoft/虹软原本适合在 Android 本地实现人脸检测、人脸特征提取、RGB 活体、动作引导式活体流程。但本项目真机验证中，ArcFace Android V3.0 在 Android 15 上在线激活返回 `90122`，且控制台说明更偏向 Android 10 兼容范围，不能作为当前项目的广泛适配主链路。

因此已从运行代码中移除：

- ArcSoft Android 原生 `MethodChannel`。
- ArcSoft JAR/SO 和示例工程。
- 设置页中的 ArcSoft 检测/在线激活入口。
- `READ_PHONE_STATE` 权限。

若未来重新启用 ArcSoft 或其他厂商动态活体 SDK，需要重新确认：

- 虹软开发者后台创建 Android 应用。
- 获取 `APP_ID`、`SDK_KEY`。
- 下载 Android SDK 包，通常包含 AAR/JAR、`arm64-v8a` 等 so 原生库和示例工程。
- 确认授权能力包含动态活体或动作活体，而不仅是静默活体/人脸比对。
- App 端用实时视频帧，不使用单张相册图片。
- Flutter 与 Android 原生层通过 `MethodChannel` 通信。

## 推荐人脸架构

1. 注册流程：实时摄像头预览，随机动作指令，例如眨眼、张嘴、左转、右转。
2. App 端用 ML Kit 完成基础姿态和质量校验。
3. 后端通过腾讯云人脸库保存用户人脸标识并执行比对，禁止保存不必要的原始视频。
4. 打卡流程：实时动作采集通过后再做人脸比对，通过后提交签到。
5. 若后续接入金融级动态活体 SDK，应新增独立 `FaceProvider`，不要改动打卡业务主流程。

## 当前项目已预留的配置项

Flutter 构建参数：

```bash
flutter build apk --debug ^
  --dart-define API_BASE_URL=http://127.0.0.1:8080 ^
  --dart-define AMAP_ANDROID_KEY=your_amap_key ^
  -PAMAP_ANDROID_KEY=your_amap_key
```

`--dart-define AMAP_ANDROID_KEY` 用于 App 内能力展示，`-PAMAP_ANDROID_KEY` 用于 Android Manifest 注入高德原生 SDK Key。

当前项目已接入高德 Android 定位 SDK 的原生通道：

- `android/app/build.gradle.kts`：高德定位 SDK 依赖和 `AMAP_ANDROID_KEY` Manifest 占位。
- `android/app/src/main/AndroidManifest.xml`：高德 Key 和 `APSService`。
- `android/app/src/main/kotlin/com/nhu/aisizheng/MainActivity.kt`：`MethodChannel` 一次高精度定位。
- `mobile/lib/services/native_location_service.dart`：Flutter 封装。
- `LocationService.getCurrentLocation(forceRefresh: true)`：优先高德，失败回退系统定位。

## 后续可能补充的材料

- 若需要腾讯定位备选链路：腾讯位置服务 Key、Android SDK 依赖和隐私合规配置。
- 若需要金融级动态活体：正式厂商 SDK、企业/学校主体资质、动作活体授权说明、计费和试点许可。
