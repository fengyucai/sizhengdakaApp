import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _status;
  bool _faceRegistered = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ApiService.getTodayStatus();
      bool faceRegistered = true;
      try {
        final faceStatus = await ApiService.getFaceStatus();
        faceRegistered = faceStatus['faceRegistered'] == true;
      } catch (_) {
        faceRegistered = true;
      }

      if (!mounted) return;
      setState(() {
        _status = status;
        _faceRegistered = faceRegistered;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI思政打卡'), actions: [
        IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.go('/messages')),
        IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.go('/profile')),
      ]),
      body: RefreshIndicator(
        onRefresh: _loadStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_loading) const SizedBox(height: 12),
            if (!_faceRegistered) ...[
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.face_retouching_natural, color: Colors.orange),
                  title: const Text('请先完成人脸注册'),
                  subtitle: const Text('注册后可进行查寝人脸打卡'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/face/register'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('今日打卡', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatus('查寝', _status?['dorm'] ?? false),
                        _buildStatus('上课', _status?['classCheckin'] ?? false),
                        _buildStatus('实习', _status?['intern'] ?? false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildCheckinCard(
              icon: Icons.home_work_outlined,
              title: '查寝打卡',
              subtitle: '晚间定位 + 人脸签到',
              onTap: () => context.go(_faceRegistered ? '/checkin/dorm' : '/face/register'),
              done: _status?['dorm'] == true,
            ),
            const SizedBox(height: 12),
            _buildCheckinCard(
              icon: Icons.co_present_outlined,
              title: '上课打卡',
              subtitle: '课堂定位 / 扫码签到',
              onTap: () => context.go('/checkin/class'),
              done: _status?['classCheckin'] == true,
            ),
            const SizedBox(height: 12),
            _buildCheckinCard(
              icon: Icons.business_center_outlined,
              title: '实习打卡',
              subtitle: '定位签到 + 工作日志',
              onTap: () => context.go('/checkin/intern'),
              done: _status?['intern'] == true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(String label, bool done) {
    return Column(
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 36, color: done ? Colors.green : Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: done ? Colors.green : Colors.grey)),
      ],
    );
  }

  Widget _buildCheckinCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool done,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: done
            ? const Chip(label: Text('已完成', style: TextStyle(color: Colors.green, fontSize: 12)))
            : const Icon(Icons.chevron_right),
        onTap: done ? null : onTap,
      ),
    );
  }
}
