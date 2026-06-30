import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_stream_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  bool _faceRegistered = true;
  bool _loading = true;
  int _unreadCount = 0;
  int _activeClassSessionCount = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
    _startNotificationStream();
  }

  Future<void> _startNotificationStream() async {
    final auth = context.read<AuthService>();
    if (auth.role != 'STUDENT') return;
    await NotificationStreamService.instance.start();
    _notificationSubscription ??=
        NotificationStreamService.instance.stream.listen(_handleNotification);
  }

  void _handleNotification(Map<String, dynamic> notification) {
    if (!mounted) return;
    _loadStatus();
    final relatedType = '${notification['relatedType'] ?? ''}';
    if (relatedType == 'CLASS_SESSION') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification['title']?.toString() ?? '收到新的课堂签到'),
          action: SnackBarAction(
            label: '去签到',
            onPressed: () async {
              await context.push('/checkin/class');
              if (mounted) _loadStatus();
            },
          ),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ApiService.getTodayStatus();
      var unreadCount = 0;
      try {
        unreadCount = await ApiService.getUnreadNotificationCount();
      } catch (_) {
        unreadCount = 0;
      }
      var activeClassSessionCount = 0;
      try {
        activeClassSessionCount =
            (await ApiService.getActiveClassSessions()).length;
      } catch (_) {
        activeClassSessionCount = 0;
      }
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
        _unreadCount = unreadCount;
        _activeClassSessionCount = activeClassSessionCount;
        _loading = false;
      });
      if (!faceRegistered && mounted) {
        context.go('/face/register');
      }
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      if (message.contains('未登录') ||
          message.contains('Token') ||
          message.contains('401')) {
        await context.read<AuthService>().logout();
        if (mounted) context.go('/login');
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('首页状态加载失败：${_friendlyError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI思政打卡'), actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await context.push('/messages');
                  if (mounted) _loadStatus();
                }),
            if (_unreadCount > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile')),
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
                  leading: const Icon(Icons.face_retouching_natural,
                      color: Colors.orange),
                  title: const Text('请先完成人脸注册'),
                  subtitle: const Text('注册后可进行查寝人脸打卡'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/face/register'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('今日打卡',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
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
              onTap: () async {
                await context
                    .push(_faceRegistered ? '/checkin/dorm' : '/face/register');
                if (mounted) _loadStatus();
              },
              done: _status?['dorm'] == true,
            ),
            const SizedBox(height: 12),
            _buildCheckinCard(
              icon: Icons.co_present_outlined,
              title: '上课打卡',
              subtitle: _activeClassSessionCount > 0
                  ? '有 $_activeClassSessionCount 个课堂签到待处理'
                  : '课堂定位 / 扫码签到',
              onTap: () async {
                await context.push('/checkin/class');
                if (mounted) _loadStatus();
              },
              done: _status?['classCheckin'] == true,
              enabled: true,
              badgeText: _activeClassSessionCount > 0 ? '待签到' : null,
              badgeColor:
                  _activeClassSessionCount > 0 ? Colors.orange : null,
            ),
            const SizedBox(height: 12),
            _buildCheckinCard(
              icon: Icons.business_center_outlined,
              title: '实习打卡',
              subtitle: '定位签到 + 工作日志',
              onTap: () async {
                await context.push('/checkin/intern');
                if (mounted) _loadStatus();
              },
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
    bool enabled = true,
    String? badgeText,
    Color? badgeColor,
  }) {
    final effectiveBadgeText = badgeText ?? (done ? '已完成' : null);
    final effectiveBadgeColor =
        badgeColor ?? (done ? Colors.green : Colors.grey);
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: effectiveBadgeText != null
            ? Chip(
                label: Text(effectiveBadgeText,
                    style:
                        TextStyle(color: effectiveBadgeColor, fontSize: 12)))
            : const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
