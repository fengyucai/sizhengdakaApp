import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const _storage = FlutterSecureStorage();

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
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

  static Map<String, dynamic> _dataOrThrow(
    Response<dynamic> res,
    String fallbackMessage,
  ) {
    if (res.data is! Map) {
      throw Exception(fallbackMessage);
    }
    final body = Map<String, dynamic>.from(res.data as Map);
    if (body['code'] != 200 || body['data'] == null) {
      throw Exception(body['message'] ?? fallbackMessage);
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  // Auth
  static Future<Map<String, dynamic>> login(
      String studentId, String password) async {
    final res = await dio.post('/auth/login', data: {
      'studentId': studentId,
      'password': password,
    });
    return res.data['data'];
  }

  // Checkin
  static Future<Map<String, dynamic>> dormCheckin({
    required double lat,
    required double lng,
    required int siteId,
    String? device,
    String? faceImage,
  }) async {
    final res = await dio.post('/checkin/dorm', data: {
      'latitude': lat,
      'longitude': lng,
      'siteId': siteId,
      'deviceInfo': device,
      'faceImage': faceImage,
    });
    return _dataOrThrow(res, '查寝打卡失败');
  }

  static Future<Map<String, dynamic>> classCheckin({
    double? lat,
    double? lng,
    int? siteId,
    int? sessionId,
    String? device,
    String? faceImage,
  }) async {
    final res = await dio.post('/checkin/class', data: {
      'latitude': lat,
      'longitude': lng,
      'siteId': siteId,
      'sessionId': sessionId,
      'deviceInfo': device,
      'faceImage': faceImage,
    });
    return _dataOrThrow(res, '课堂签到失败');
  }

  static Future<Map<String, dynamic>> classScanCheckin({
    required String qrToken,
    double? lat,
    double? lng,
    String? device,
    String? faceImage,
  }) async {
    final res = await dio.post('/checkin/class/scan', data: {
      'qrToken': qrToken,
      'latitude': lat,
      'longitude': lng,
      'deviceInfo': device,
      'faceImage': faceImage,
    });
    return _dataOrThrow(res, '扫码签到失败');
  }

  static Future<List<Map<String, dynamic>>> getActiveClassSessions() async {
    final res = await dio.get('/checkin/class/sessions/active');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取课堂签到场次失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> internCheckin({
    required double lat,
    required double lng,
    required int siteId,
    String? device,
    required String logContent,
  }) async {
    final res = await dio.post('/checkin/intern', data: {
      'latitude': lat,
      'longitude': lng,
      'siteId': siteId,
      'deviceInfo': device,
      'logContent': logContent,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '提交实习打卡失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> getTodayStatus() async {
    final res = await dio.get('/checkin/status/today');
    if (res.data['code'] != 200 || res.data['data'] == null) {
      throw Exception(res.data['message'] ?? '获取今日打卡状态失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> getMyStatistics() async {
    final res = await dio.get('/checkin/statistics/me');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取考勤统计失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await dio.post('/auth/password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '修改密码失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getCheckinRecords(
      {int limit = 30}) async {
    final res =
        await dio.get('/checkin/records', queryParameters: {'limit': limit});
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

  static Future<Map<String, dynamic>> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final res = await dio.get('/location/reverse', queryParameters: {
      'lat': lat,
      'lng': lng,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取详细地址失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> getFaceStatus() async {
    final res = await dio.get('/face/status');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取人脸状态失败');
    }
    return res.data['data'];
  }

  static Future<Map<String, dynamic>> registerFace(
      List<String> imagePaths) async {
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

  static Future<int> getUnreadNotificationCount() async {
    final data = await getNotifications();
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
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

  static Future<List<Map<String, dynamic>>> getInternLogs() async {
    final res = await dio.get('/intern/logs');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取实习日志失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  // Teacher / counselor management APIs
  static Future<Map<String, dynamic>> getTeacherDashboard() async {
    final res = await dio.get('/manage/dashboard');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取管理看板失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getManageLeaves() async {
    final res = await dio.get('/manage/leave/list');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取请假审批列表失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> approveLeave(int id, {String? comment}) async {
    final res =
        await dio.post('/manage/leave/$id/approve', data: {'comment': comment});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '批准请假失败');
    }
  }

  static Future<void> rejectLeave(int id, {String? comment}) async {
    final res =
        await dio.post('/manage/leave/$id/reject', data: {'comment': comment});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '驳回请假失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getManageAppeals({
    String status = 'PENDING',
  }) async {
    final res =
        await dio.get('/manage/appeals', queryParameters: {'status': status});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取申诉列表失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> reviewAppeal(
    int id, {
    required bool approved,
    String? comment,
  }) async {
    final res = await dio.post('/manage/appeal/$id/review', data: {
      'approved': approved,
      'comment': comment,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '审核申诉失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getManageInternLogs() async {
    final res = await dio.get('/manage/intern/logs');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取实习日志失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> reviewInternLog(int id, {required String comment}) async {
    final res = await dio
        .post('/manage/intern/log/$id/review', data: {'comment': comment});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '评阅实习日志失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getManageStudents() async {
    final res = await dio.get('/manage/students');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取学生列表失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getDormTodayLocations() async {
    final res = await dio.get('/manage/dorm/today-locations');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取查寝位置失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> getMobileClassWorkbench() async {
    final res = await dio.get('/manage/class/mobile');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取课堂签到管理失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getManageClassSessions({
    int? classId,
  }) async {
    final res = await dio.get('/manage/class/sessions',
        queryParameters: classId == null ? null : {'classId': classId});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取课堂场次失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> closeManageClassSession(int id) async {
    final res = await dio.post('/manage/class/session/$id/close');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '关闭课堂场次失败');
    }
  }

  static Future<Map<String, dynamic>> getManageSessionAttendance(
      int sessionId) async {
    final res = await dio.get('/manage/class/session/$sessionId/attendance');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取课堂考勤明细失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> generateClassQr({
    required int sessionId,
    int expiresInSeconds = 30,
  }) async {
    final res = await dio.post('/checkin/class/qr', data: {
      'sessionId': sessionId,
      'expiresInSeconds': expiresInSeconds,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '生成课堂动态码失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> createMobileClassSession({
    required String mode,
    int? siteId,
    String? courseName,
    String? teacherName,
    int durationMinutes = 45,
  }) async {
    final res = await dio.post('/manage/class/mobile-session', data: {
      'mode': mode,
      'siteId': siteId,
      'courseName': courseName,
      'teacherName': teacherName,
      'durationMinutes': durationMinutes,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '创建课堂签到失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> manualClassCheckin({
    required int userId,
    required int siteId,
    int? sessionId,
  }) async {
    final res = await dio.post('/manage/class/manual-checkin', data: {
      'userId': userId,
      'siteId': siteId,
      'sessionId': sessionId,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '普通签到失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getManageAlerts() async {
    final res = await dio.get('/manage/alerts');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取预警失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> handleManageAlert(int id) async {
    final res = await dio.post('/manage/alerts/$id/handle');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '处理预警失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getManageSites({
    String? type,
    bool activeOnly = false,
  }) async {
    final params = <String, dynamic>{'activeOnly': activeOnly};
    if (type != null) params['type'] = type;
    final res = await dio.get('/manage/sites', queryParameters: params);
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取打卡点失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createManageSite({
    required String name,
    required String type,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? address,
  }) async {
    final res = await dio.post('/manage/sites', data: {
      'name': name,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'address': address,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '创建打卡点失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<void> updateManageSite({
    required int id,
    required String name,
    required String type,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? address,
  }) async {
    final res = await dio.post('/manage/sites/$id', data: {
      'name': name,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'address': address,
    });
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '更新打卡点失败');
    }
  }

  static Future<void> disableManageSite(int id) async {
    final res = await dio.post('/manage/sites/$id/disable');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '停用打卡点失败');
    }
  }

  static Future<void> enableManageSite(int id) async {
    final res = await dio.post('/manage/sites/$id/enable');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '启用打卡点失败');
    }
  }

  static Future<List<Map<String, dynamic>>> getManageAuditLogs({
    int limit = 50,
  }) async {
    final res =
        await dio.get('/manage/audit/logs', queryParameters: {'limit': limit});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取审计日志失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> geocodeAddress({
    required String address,
    String city = '衡阳',
  }) async {
    final res = await dio.get('/location/geocode',
        queryParameters: {'address': address, 'city': city});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '地址解析失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> getWeeklyReport() async {
    final res = await dio.get('/manage/report/weekly');
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取周报失败');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getTrendReport({
    int days = 7,
  }) async {
    final res =
        await dio.get('/manage/report/trend', queryParameters: {'days': days});
    if (res.data['code'] != 200) {
      throw Exception(res.data['message'] ?? '获取趋势数据失败');
    }
    return (res.data['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}T${two(value.hour)}:${two(value.minute)}:00';
  }
}
