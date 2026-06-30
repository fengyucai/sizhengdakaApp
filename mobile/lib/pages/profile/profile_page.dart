import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                      radius: 32, child: Icon(Icons.person, size: 36)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.realName ?? '未登录',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('用户ID: ${auth.userId ?? "-"}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
              Icons.event_busy_outlined, '请假申请', () => context.push('/leave')),
          _buildMenuItem(
              Icons.checklist, '打卡记录', () => context.push('/records')),
          _buildMenuItem(
              Icons.assignment, '考勤统计', () => context.push('/attendance')),
          _buildMenuItem(
              Icons.lock_reset, '修改密码', () => context.push('/password/change')),
          _buildMenuItem(Icons.settings, '设置', () => context.push('/settings')),
          _buildMenuItem(Icons.info_outline, '关于', () => context.push('/about')),
          const Divider(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                auth.logout();
                context.go('/login');
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
