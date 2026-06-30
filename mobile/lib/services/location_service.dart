import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_location_service.dart';

class AppLocationResult {
  const AppLocationResult({
    required this.position,
    this.address,
    this.provider = 'SYSTEM',
  });

  final Position position;
  final Map<String, dynamic>? address;
  final String provider;
}

class LocationService {
  final _nativeLocationService = NativeLocationService();

  Future<AppLocationResult> getCurrentLocation({
    bool forceRefresh = false,
    Duration cacheMaxAge = const Duration(minutes: 1),
    double cacheMaxAccuracy = 80,
  }) async {
    await _ensurePermission();

    if (forceRefresh) {
      final native = await _nativeLocationService.getAmapLocation();
      if (native != null) {
        return AppLocationResult(
          position: native.position,
          address: native.address,
          provider: native.provider,
        );
      }
    }

    final position = await getCurrentPosition(
      forceRefresh: forceRefresh,
      cacheMaxAge: cacheMaxAge,
      cacheMaxAccuracy: cacheMaxAccuracy,
    );
    return AppLocationResult(position: position);
  }

  Future<Position> getCurrentPosition({
    bool forceRefresh = false,
    Duration cacheMaxAge = const Duration(minutes: 1),
    double cacheMaxAccuracy = 80,
  }) async {
    await _ensurePermission();

    final prefs = await SharedPreferences.getInstance();
    final fastMode = prefs.getBool('fastLocationEnabled') ?? true;

    if (fastMode && !forceRefresh) {
      final cached = await Geolocator.getLastKnownPosition();
      if (_isUsableCachedPosition(
        cached,
        maxAge: cacheMaxAge,
        maxAccuracy: cacheMaxAccuracy,
      )) {
        return cached!;
      }
    }

    if (!forceRefresh) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 2),
        );
      } on TimeoutException {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: forceRefresh
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3),
      );
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (!forceRefresh && lastKnown != null) return lastKnown;

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 6),
      );
    }
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('请开启GPS定位服务');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('定位权限被拒绝');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝，请在设置中开启');
    }
  }

  bool _isUsableCachedPosition(
    Position? position, {
    required Duration maxAge,
    required double maxAccuracy,
  }) {
    if (position == null) return false;
    final age = DateTime.now().difference(position.timestamp);
    return age <= maxAge && position.accuracy <= maxAccuracy;
  }

  /// Haversine公式 — 计算两点球面距离(米)
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _rad(double d) => d * pi / 180.0;
}
