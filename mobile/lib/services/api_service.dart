import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const baseUrl = 'http://localhost:8080';
  static final _storage = FlutterSecureStorage();

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'accessToken');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        _storage.deleteAll();
      }
      handler.next(error);
    },
  ));

  // Auth
  static Future<Map<String, dynamic>> login(String studentId, String password) async {
    final res = await dio.post('/auth/login', data: {
      'studentId': studentId,
      'password': password,
    });
    return res.data['data'];
  }

  // Checkin
  static Future<Map<String, dynamic>> dormCheckin({
    required double lat, required double lng, required int siteId, String? device, String? faceImage,
  }) async {
    final res = await dio.post('/checkin/dorm', data: {
      'latitude': lat, 'longitude': lng, 'siteId': siteId, 'deviceInfo': device, 'faceImage': faceImage,
    });
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> classCheckin({
    required double lat, required double lng, required int siteId, String? device, String? faceImage,
  }) async {
    final res = await dio.post('/checkin/class', data: {
      'latitude': lat, 'longitude': lng, 'siteId': siteId, 'deviceInfo': device, 'faceImage': faceImage,
    });
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> classScanCheckin({
    required String qrToken, required double lat, required double lng, String? device, String? faceImage,
  }) async {
    final res = await dio.post('/checkin/class/scan', data: {
      'qrToken': qrToken, 'latitude': lat, 'longitude': lng, 'deviceInfo': device, 'faceImage': faceImage,
    });
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> internCheckin({
    required double lat, required double lng, required int siteId, String? device, required String logContent,
  }) async {
    final res = await dio.post('/checkin/intern', data: {
      'latitude': lat, 'longitude': lng, 'siteId': siteId, 'deviceInfo': device, 'logContent': logContent,
    });
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> getTodayStatus() async {
    final res = await dio.get('/checkin/status/today');
    return res.data['data'];
  }

  static Future<List<Map<String, dynamic>>> getCheckinRecords({int limit = 30}) async {
    final res = await dio.get('/checkin/records', queryParameters: {'limit': limit});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取打卡记录失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> appealCheckinRecord({
    required int id,
    required String reason,
  }) async {
    final res = await dio.post('/checkin/$id/appeal', data: {'reason': reason});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '提交申诉失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> getBestCheckinSite({
    required String type,
    required double lat,
    required double lng,
  }) async {
    final res = await dio.get('/checkin/sites/best', queryParameters: {
      'type': type,
      'lat': lat,
      'lng': lng,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取打卡点失败');
    }
    final data = Map<String, dynamic>.from(res.data['data'] as Map);
    data['id'] = (data['id'] as num).toInt();
    data['distanceMeters'] = (data['distanceMeters'] as num).toInt();
    data['radiusMeters'] = (data['radiusMeters'] as num).toInt();
    return data;
  }

  static Future<Map<String, dynamic>> getFaceStatus() async {
    final res = await dio.get('/face/status');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取人脸状态失败');
    }
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> registerFace(List<String> imagePaths) async {
    final files = <MultipartFile>[];
    for (final path in imagePaths) {
      files.add(await MultipartFile.fromFile(path));
    }

    final res = await dio.post(
      '/face/register',
      data: FormData.fromMap({'images': files}),
      options: Options(contentType: 'multipart/form-data'),
    );
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '人脸注册失败');
    }
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await dio.get('/notifications');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取消息失败');
    }
    return res.data['data'];
  }

  static Future<void> markNotificationRead(int id) async {
    final res = await dio.post('/notifications/$id/read');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '标记消息已读失败');
    }
  }

  static Future<void> markAllNotificationsRead() async {
    final res = await dio.post('/notifications/read-all');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '全部已读失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    final res = await dio.get('/leave/list');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取请假记录失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> applyLeave({
    required String leaveType,
    required DateTime startTime,
    required DateTime endTime,
    required String reason,
  }) async {
    final res = await dio.post('/leave/apply', data: {
      'leaveType': leaveType,
      'startTime': _formatDateTime(startTime),
      'endTime': _formatDateTime(endTime),
      'reason': reason,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '提交请假申请失败');
    }
    return res.data['data'];
  }

  static Future<void> cancelLeave(int id) async {
    final res = await dio.post('/leave/$id/cancel');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '取消请假申请失败');
    }
  }

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}T${two(value.hour)}:${two(value.minute)}:00';
  }
}
