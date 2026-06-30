import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class AttendanceStatsPage extends StatefulWidget {
  const AttendanceStatsPage({super.key});

  @override
  State<AttendanceStatsPage> createState() => _AttendanceStatsPageState();
}

class _AttendanceStatsPageState extends State<AttendanceStatsPage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await ApiService.getMyStatistics();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('考勤统计加载失败：${_friendlyError(e)}'),
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
      appBar: AppBar(
        title: const Text('考勤统计'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_stats?['rangeLabel']?.toString() ?? '近30日',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _statCard('有效打卡', _stats?['successCount'], Colors.green),
                      _statCard('异常记录', _stats?['failedCount'], Colors.red),
                      _statCard('查寝', _stats?['dormCount'], Colors.teal),
                      _statCard('上课', _stats?['classCount'], Colors.blue),
                      _statCard('实习', _stats?['internCount'], Colors.purple),
                      _statCard('实习日志', _stats?['internLogCount'], Colors.indigo),
                      _statCard('待审请假', _stats?['pendingLeaves'], Colors.orange),
                      _statCard('待审申诉', _stats?['pendingAppeals'], Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('最近记录', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final record in (_stats?['recentRecords'] as List? ?? []))
                    _recordTile(Map<String, dynamic>.from(record as Map)),
                  if ((_stats?['recentRecords'] as List? ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                          child: Text('暂无考勤记录',
                              style: TextStyle(color: Colors.grey))),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _statCard(String label, dynamic value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, color: color),
            const SizedBox(height: 8),
            Text('${(value as num?)?.toInt() ?? 0}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> record) {
    final success = record['status'] == 'SUCCESS';
    return Card(
      child: ListTile(
        leading: Icon(success ? Icons.check_circle : Icons.error_outline,
            color: success ? Colors.green : Colors.red),
        title: Text('${record['typeLabel'] ?? record['type']}'),
        subtitle: Text(_formatTime(record['time'])),
        trailing: Text(success ? '成功' : '异常',
            style: TextStyle(color: success ? Colors.green : Colors.red)),
      ),
    );
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 16) return text.substring(0, 16).replaceFirst('T', ' ');
    return text;
  }
}
