import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<Map<String, dynamic>> _messages = [];
  int _unreadCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getNotifications();
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = items;
        _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _show('消息加载失败：${_friendlyError(e)}', Colors.red);
    }
  }

  Future<void> _markRead(Map<String, dynamic> message) async {
    if (message['read'] == true) return;
    final id = (message['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await ApiService.markNotificationRead(id);
      await _loadMessages();
    } catch (_) {
      if (!mounted) return;
      _show('消息状态更新失败', Colors.red);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      await _loadMessages();
    } catch (_) {
      if (!mounted) return;
      _show('全部已读失败', Colors.red);
    }
  }

  void _showMessage(Map<String, dynamic> message) {
    _markRead(message);
    final isClassSession = message['relatedType'] == 'CLASS_SESSION';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message['title']?.toString() ?? '消息详情'),
        content: Text(message['content']?.toString() ?? ''),
        actions: [
          if (isClassSession)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/checkin/class');
              },
              child: const Text('去签到'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_unreadCount > 0 ? '消息中心 ($_unreadCount)' : '消息中心'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          TextButton(
            onPressed: _unreadCount > 0 ? _markAllRead : null,
            child: const Text('全部已读', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无消息', style: TextStyle(color: Colors.grey))),
        ],
      );
    }
    return ListView.separated(
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = _messages[index];
        final read = message['read'] == true;
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: read
                    ? Colors.grey.shade200
                    : _typeColor(message['type']).withValues(alpha: 0.12),
                child: Icon(
                  read ? Icons.notifications_none : _typeIcon(message['type']),
                  color: read ? Colors.grey : _typeColor(message['type']),
                ),
              ),
              if (!read)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            message['title']?.toString() ?? '',
            style: TextStyle(
              fontWeight: read ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(
            message['content']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatTime(message['createdAt']),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          onTap: () => _showMessage(message),
        );
      },
    );
  }

  IconData _typeIcon(dynamic type) {
    return switch (type) {
      'WARNING' => Icons.warning_amber_outlined,
      'REMINDER' => Icons.alarm_outlined,
      'APPROVAL' => Icons.fact_check_outlined,
      _ => Icons.info_outline,
    };
  }

  Color _typeColor(dynamic type) {
    return switch (type) {
      'WARNING' => Colors.red,
      'REMINDER' => Colors.orange,
      'APPROVAL' => Colors.blue,
      _ => Colors.teal,
    };
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 16) return text.substring(5, 16).replaceFirst('T', ' ');
    return text;
  }
}
