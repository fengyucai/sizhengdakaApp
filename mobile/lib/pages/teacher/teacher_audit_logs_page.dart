import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class TeacherAuditLogsPage extends StatefulWidget {
  const TeacherAuditLogsPage({super.key});

  @override
  State<TeacherAuditLogsPage> createState() => _TeacherAuditLogsPageState();
}

class _TeacherAuditLogsPageState extends State<TeacherAuditLogsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showFeedback = false}) async {
    setState(() => _loading = true);
    try {
      final logs = await ApiService.getManageAuditLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('审计日志已刷新')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('操作审计'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _load(showFeedback: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_loading) const SizedBox(height: 12),
            if (!_loading && _logs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('暂无审计日志')),
              ),
            for (final log in _logs) _buildLogCard(log),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final actionLabel = '${log['actionLabel'] ?? log['action'] ?? ''}';
    final operatorName = '${log['operatorName'] ?? '系统'}';
    final createdAt = '${log['createdAt'] ?? ''}';
    final resource = '${log['resource'] ?? ''}';
    final resourceId = (log['resourceId'] as num?)?.toInt() ?? 0;
    final ipAddress = '${log['ipAddress'] ?? ''}';
    final detail = '${log['detail'] ?? '{}'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Icon(
                    Icons.manage_history_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$operatorName · $createdAt',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMeta(
                '对象', resourceId > 0 ? '$resource #$resourceId' : resource),
            if (ipAddress.isNotEmpty) _buildMeta('来源IP', ipAddress),
            _buildMeta('详情', detail),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
