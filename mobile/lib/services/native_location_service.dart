import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/native_capability_config.dart';

class NativeLocationResult {
  const NativeLocationResult({
    required this.position,
    required this.address,
    required this.provider,
  });

  final Position position;
  final Map<String, dynamic> address;
  final String provider;
}

class NativeLocationService {
  static const _channel = MethodChannel('com.nhu.aisizheng/native_location');

  Future<NativeLocationResult?> getAmapLocation() async {
    if (!NativeCapabilityConfig.amapReady) return null;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getAmapLocation',
      );
      if (data == null) return null;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
      final position = Position(
        longitude: (data['longitude'] as num).toDouble(),
        latitude: (data['latitude'] as num).toDouble(),
        timestamp: timestamp,
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0,
        altitudeAccuracy: 0,
        heading: (data['bearing'] as num?)?.toDouble() ?? 0,
        headingAccuracy: 0,
        speed: (data['speed'] as num?)?.toDouble() ?? 0,
        speedAccuracy: 0,
      );
      return NativeLocationResult(
        position: position,
        provider: 'AMAP',
        address: {
          'provider': 'AMAP',
          'province': data['province'],
          'city': data['city'],
          'district': data['district'],
          'street': data['street'],
          'streetNumber': data['streetNumber'],
          'formattedAddress': data['address'],
          'adCode': data['adCode'],
          'cityCode': data['cityCode'],
          'locationType': data['locationType'],
        },
      );
    } on PlatformException {
      return null;
    }
  }
}
