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
}
