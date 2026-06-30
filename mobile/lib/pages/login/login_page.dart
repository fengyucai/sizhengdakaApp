import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/privacy_consent_service.dart';
import '../../config/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _studentIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restoreSession);
  }

  Future<void> _restoreSession() async {
    final authService = context.read<AuthService>();
    await authService.init();
    if (!mounted || !authService.isLoggedIn) return;
    if (!await _ensurePrivacyConsent()) return;
    await _goAfterLogin(authService.role);
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final authService = context.read<AuthService>();
    try {
      final data = await ApiService.login(
        _studentIdCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await authService.login(
        token: data['accessToken'],
        userId: data['userId'],
        realName: data['realName'],
        role: data['role'],
      );
      if (!mounted) return;
      if (!await _ensurePrivacyConsent()) return;
      await _goAfterLogin(data['role']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('登录失败: 账号或密码错误'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensurePrivacyConsent() async {
    if (await PrivacyConsentService.hasAcceptedCurrentVersion()) return true;
    if (!mounted) return false;
    context.go('/privacy/consent');
    return false;
  }

  Future<void> _goAfterLogin(String? role) async {
    if (role == 'STUDENT') {
      try {
        final faceStatus = await ApiService.getFaceStatus();
        if (!mounted) return;
        context.go(
            faceStatus['faceRegistered'] == true ? '/home' : '/face/register');
      } catch (_) {
        if (!mounted) return;
        context.go('/home');
      }
    } else if (role == 'INSTRUCTOR' || role == 'ADMIN') {
      context.go('/teacher/home');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor, Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('AI思政打卡',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('南华大学计算机学院',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 48),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _studentIdCtrl,
                            decoration: const InputDecoration(
                              labelText: '学号/工号',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('登 录',
                                      style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '账号由学院统一导入发放；首次使用默认密码登录后，请在个人中心修改密码。',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
