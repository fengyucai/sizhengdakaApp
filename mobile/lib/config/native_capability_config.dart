class NativeCapabilityConfig {
  static const amapAndroidKey =
      String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: '');

  static bool get amapReady => amapAndroidKey.isNotEmpty;

  static String get locationEngineLabel {
    if (amapReady) return '高德定位 SDK 可配置';
    return '系统融合定位';
  }

  static String get faceEngineLabel => '端侧实时动作采集 + 腾讯云人脸库比对';
}
