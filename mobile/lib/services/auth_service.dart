import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _userId;
  String? _realName;
  String? _role;
  bool _isLoggedIn = false;

  String? get userId => _userId;
  String? get realName => _realName;
  String? get role => _role;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> init() async {
    _userId = await _storage.read(key: 'userId');
    _realName = await _storage.read(key: 'realName');
    _role = await _storage.read(key: 'role');
    _isLoggedIn = await _storage.read(key: 'accessToken') != null;
    notifyListeners();
  }

  Future<void> login({
    required String token,
    required String userId,
    required String realName,
    required String role,
  }) async {
    await _storage.write(key: 'accessToken', value: token);
    await _storage.write(key: 'userId', value: userId);
    await _storage.write(key: 'realName', value: realName);
    await _storage.write(key: 'role', value: role);
    _userId = userId;
    _realName = realName;
    _role = role;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _userId = null;
    _realName = null;
    _role = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
