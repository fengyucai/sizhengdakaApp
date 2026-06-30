import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    final oldPassword = _oldCtrl.text;
    final newPassword = _newCtrl.text;
    final confirmPassword = _confirmCtrl.text;
    if (oldPassword.isEmpty) {
      _show('请输入原密码', Colors.orange);
      return;
    }
    if (newPassword.length < 6 || newPassword.length > 32) {
      _show('新密码需为6-32位', Colors.orange);
      return;
    }
    if (newPassword != confirmPassword) {
      _show('两次输入的新密码不一致', Colors.orange);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      _show('密码已修改，请妥善保管新密码', Colors.green);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      _show(text.startsWith('Exception: ') ? text.substring(11) : text,
          Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '首次使用默认密码登录后，请及时修改为本人密码。',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _oldCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '原密码',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '新密码',
              prefixIcon: Icon(Icons.password),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '确认新密码',
              prefixIcon: Icon(Icons.verified_user_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存新密码'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
