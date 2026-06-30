package com.nhu.aisizheng

import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nativeLocationChannel = "com.nhu.aisizheng/native_location"
    private var amapClient: AMapLocationClient? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeLocationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAmapLocation" -> getAmapLocation(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getAmapLocation(result: MethodChannel.Result) {
        val appKey = try {
            packageManager
                .getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
                .metaData
                ?.getString("com.amap.api.v2.apikey")
                .orEmpty()
        } catch (_: Exception) {
            ""
        }
        if (appKey.isBlank()) {
            result.error("AMAP_KEY_MISSING", "未配置高德 Android Key", null)
            return
        }

        try {
            AMapLocationClient.updatePrivacyShow(applicationContext, true, true)
            AMapLocationClient.updatePrivacyAgree(applicationContext, true)
            val option = AMapLocationClientOption().apply {
                locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
                isOnceLocation = true
                isOnceLocationLatest = true
                isNeedAddress = true
                httpTimeOut = 5000
            }
            val client = AMapLocationClient(applicationContext)
            amapClient = client
            client.setLocationOption(option)
            client.setLocationListener { location ->
                client.stopLocation()
                client.onDestroy()
                amapClient = null
                if (location != null && location.errorCode == AMapLocation.LOCATION_SUCCESS) {
                    result.success(location.toMap())
                } else {
                    result.error(
                        "AMAP_LOCATION_FAILED",
                        location?.errorInfo ?: "高德定位失败",
                        location?.errorCode
                    )
                }
            }
            client.startLocation()
        } catch (e: Exception) {
            result.error("AMAP_LOCATION_EXCEPTION", e.message ?: "高德定位异常", null)
        }
    }

    private fun AMapLocation.toMap(): Map<String, Any?> = mapOf(
        "provider" to "AMAP",
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy.toDouble(),
        "altitude" to altitude,
        "speed" to speed.toDouble(),
        "bearing" to bearing.toDouble(),
        "timestamp" to time,
        "locationType" to locationType,
        "province" to province,
        "city" to city,
        "district" to district,
        "street" to street,
        "streetNumber" to streetNum,
        "address" to address,
        "description" to description,
        "adCode" to adCode,
        "cityCode" to cityCode
    )

    override fun onDestroy() {
        amapClient?.onDestroy()
        amapClient = null
        super.onDestroy()
    }
}
