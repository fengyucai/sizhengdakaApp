# 百度动态活体人脸识别改造方案

## 1. 当前问题

当前移动端人脸流程基于 `image_picker` 调起前置相机拍照：

- 注册页要求拍摄正面、微左、微右三张照片。
- 查寝、上课、扫码打卡上传单张 Base64 图片。
- 后端调用百度人脸库注册和搜索接口，并在搜索时使用 `liveness_control=HIGH`。

这个方案只能算“单图人脸识别 + 静默活体”。它不能满足正式管理场景里的动态活体要求，因为学生可以用已有照片、屏幕翻拍、视频回放等方式绕过前端拍照入口。

## 2. 目标方案

将人脸能力升级为：

1. 登录后首次强制进行动态活体人脸录入。
2. 录入时由百度活体/核身能力验证真人动作，例如眨眼、张嘴、摇头、点头等。
3. 活体通过后，再将合格人脸图注册到百度人脸库。
4. 后续查寝、上课、扫码打卡均先完成一次实时动态活体验证。
5. 打卡接口不再信任普通 `faceImage`，而是校验后端签发的短期 `faceVerifyToken`。

## 3. 推荐接入路线

优先接入百度正式的人脸核身/动作活体能力，而不是自研动作识别。

推荐流程：

- 移动端集成百度 Android 活体/核身 SDK，Flutter 通过 MethodChannel 调用原生能力。
- 后端负责签发一次性活体会话、记录业务流水、接收百度验证结果。
- 百度 SDK 完成动作提示、视频帧采集、活体判断和攻击防护。
- 活体通过后，后端调用百度人脸库注册或搜索接口。

如果当前百度控制台只开通了“人脸识别”而未开通“活体检测/人脸核身”能力，需要先在百度智能云控制台开通对应产品，并下载 Android SDK、配置授权文件或 License。

## 4. 新接口契约

### 4.1 发起人脸录入会话

`POST /face/enrollment/session`

返回：

```json
{
  "sessionId": "uuid",
  "userId": 4,
  "challengeActions": ["BLINK", "TURN_HEAD"],
  "expiresInSeconds": 180
}
```

说明：

- 如果使用百度 SDK 自带动作编排，`challengeActions` 可为空，仅保留会话。
- 会话只能使用一次，超时作废。

### 4.2 提交动态活体录入结果

`POST /face/enrollment/complete`

请求：

```json
{
  "sessionId": "uuid",
  "livenessToken": "baidu-or-sdk-result-token",
  "bestFaceImage": "base64"
}
```

后端处理：

- 校验会话归属当前登录用户。
- 校验百度活体结果通过。
- 将 `bestFaceImage` 注册到百度人脸库。
- 标记用户 `face_registered=true`。
- 记录 `face_registered_at`、`face_provider`、`liveness_mode`。

### 4.3 发起打卡前人脸验证会话

`POST /face/verify/session`

请求：

```json
{
  "bizType": "DORM"
}
```

返回：

```json
{
  "sessionId": "uuid",
  "challengeActions": ["BLINK", "OPEN_MOUTH"],
  "expiresInSeconds": 120
}
```

### 4.4 完成打卡前人脸验证

`POST /face/verify/complete`

请求：

```json
{
  "sessionId": "uuid",
  "livenessToken": "baidu-or-sdk-result-token",
  "bestFaceImage": "base64"
}
```

返回：

```json
{
  "faceVerifyToken": "jwt-or-random-token",
  "score": 93.6,
  "livenessPassed": true,
  "expiresInSeconds": 90
}
```

后端处理：

- 校验动态活体通过。
- 用 `bestFaceImage` 调用百度人脸搜索。
- 搜索结果必须匹配当前登录用户。
- 签发一次性、短有效期 `faceVerifyToken`。

### 4.5 打卡接口改造

现有：

```json
{
  "lat": 26.88,
  "lng": 112.51,
  "siteId": 1,
  "faceImage": "base64"
}
```

改为：

```json
{
  "lat": 26.88,
  "lng": 112.51,
  "siteId": 1,
  "faceVerifyToken": "short-lived-token"
}
```

后端要求：

- `DORM`、`CLASS` 必须提供有效 `faceVerifyToken`。
- token 必须属于当前用户、当前业务类型，未过期，未使用。
- 打卡成功或失败后都应将 token 标记为已使用，避免复用。

## 5. 后端改造清单

新增表或实体：

- `face_liveness_session`
  - `id`
  - `user_id`
  - `biz_type`
  - `purpose`: `ENROLLMENT` / `CHECKIN_VERIFY`
  - `challenge_actions`
  - `status`: `CREATED` / `PASSED` / `FAILED` / `EXPIRED`
  - `expires_at`
  - `created_at`

- `face_verify_token`
  - `token_hash`
  - `user_id`
  - `biz_type`
  - `score`
  - `expires_at`
  - `used_at`
  - `created_at`

新增服务：

- `BaiduLivenessService`
  - 发起/校验百度活体会话。
  - 解析百度 SDK 或服务端返回结果。
  - 输出统一的 `LivenessResult`。

- `FaceVerificationService`
  - 管理录入会话。
  - 管理打卡验证会话。
  - 签发和消费 `faceVerifyToken`。

改造现有服务：

- `BaiduFaceService`
  - 保留人脸库注册和搜索。
  - 注册接口改为只接受活体通过后的最佳人脸图。
  - 搜索阈值和活体阈值配置化。

- `CheckinService`
  - 不再直接接受并信任 `faceImage`。
  - 对 `DORM`、`CLASS` 强制消费 `faceVerifyToken`。
  - 记录人脸相似度、活体通过状态、验证会话 ID。

## 6. 移动端改造清单

新增原生桥接：

- `android/app/src/main/kotlin/.../BaiduLivenessPlugin.kt`
- Flutter MethodChannel：`baidu_liveness`

Flutter 服务：

- 替换 `FaceCaptureService` 为 `FaceLivenessService`。
- 暴露：
  - `startEnrollment(session)`
  - `startCheckinVerification(session)`

页面改造：

- `face_register_page.dart`
  - 从“三张照片采集”改为“动态活体录入”。
  - 显示动作进度、失败重试、成功入库。

- `dorm_checkin_page.dart`
  - 点击人脸验证时先创建 `/face/verify/session`。
  - 调用百度活体 SDK。
  - 完成后拿到 `faceVerifyToken`。
  - 提交打卡时传 `faceVerifyToken`。

- `class_checkin_page.dart`
  - 同查寝。

- `class_qr_scan_page.dart`
  - 扫码前或扫码后提交前必须完成动态活体。
  - 二维码 token 和 `faceVerifyToken` 一起提交。

## 7. 安全要求

- 不在移动端保存人脸原图。
- 不把百度 Secret Key 放进 APK。
- `faceVerifyToken` 有效期建议 60-120 秒。
- `faceVerifyToken` 一次性使用。
- 活体会话必须绑定用户、业务类型和设备信息。
- 后端记录失败原因，便于申诉和审计。
- 录入原图如需留存，应设置最短保留周期并脱敏访问。

## 8. 实施顺序

1. 确认百度控制台已开通动态活体/人脸核身能力，并拿到 Android SDK、License、接入文档。
2. 后端新增活体会话和验证 token 数据模型。
3. 后端新增 `/face/enrollment/session`、`/face/enrollment/complete`、`/face/verify/session`、`/face/verify/complete`。
4. 移动端添加 Android 原生 SDK 和 MethodChannel。
5. 改造人脸注册页为动态活体录入。
6. 改造查寝、上课、扫码打卡为 `faceVerifyToken` 模式。
7. 删除旧的 Mock 降级入口；未配置百度能力时直接阻断注册和打卡。
8. 真机测试照片攻击、屏幕翻拍、视频回放、后台恢复、弱网重试。

## 9. 临时过渡策略

在正式百度活体 SDK 接入前，可以做以下过渡，但不能称为正式动态活体：

- 后端随机下发动作序列。
- 移动端用 camera 连续采集短视频或多帧图片。
- 后端检查采集时间戳、帧间差异、图片质量。
- 仍调用百度单图人脸搜索。

该方案只能提高攻击成本，不能替代百度正式活体/核身能力。
