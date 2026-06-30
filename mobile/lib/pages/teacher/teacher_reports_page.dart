import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class TeacherReportsPage extends StatefulWidget {
  const TeacherReportsPage({super.key});

  @override
  State<TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<TeacherReportsPage> {
  Map<String, dynamic>? _weekly;
  Map<String, dynamic>? _insights;
  List<Map<String, dynamic>> _trend = [];
  bool _loading = true;
  String? _error;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final weekly = await ApiService.getWeeklyReport();
      final trend = await ApiService.getTrendReport(days: _days);
      final insights = await ApiService.getReportInsights(days: _days);
      if (!mounted) return;
      setState(() {
        _weekly = weekly;
        _insights = insights;
        _trend = trend;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!), backgroundColor: Colors.red),
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
        title: const Text('统计报表'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            onSelected: (value) {
              setState(() {
                _days = value;
                _loading = true;
              });
              _load();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('近 7 天')),
              PopupMenuItem(value: 14, child: Text('近 14 天')),
              PopupMenuItem(value: 31, child: Text('近 31 天')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('周报概览',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _rateCard('查寝周报', _weekly?['dormRate'],
                          Icons.home_outlined, Colors.blue),
                      _rateCard('课堂出勤周报', _weekly?['classRate'],
                          Icons.co_present_outlined, Colors.green),
                      _rateCard('实习日志周报', _weekly?['internRate'],
                          Icons.work_outline, Colors.purple),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('周内记录总数'),
                          trailing: Text(
                              '${(_weekly?['recordCount'] as num?)?.toInt() ?? 0} 条'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('出勤趋势',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (final item in _trend) _trendCard(item),
                      const SizedBox(height: 20),
                      _buildInsights(),
                    ],
                  ),
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(_error ?? '加载失败', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _load();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    final insights = _insights ?? {};
    final summary =
        Map<String, dynamic>.from((insights['summary'] as Map?) ?? {});
    final classSummary = ((insights['classSummary'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final abnormalStudents = ((insights['abnormalStudents'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final leaveConflicts = ((insights['leaveConflicts'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('统计洞察', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _smallMetric('学生', summary['studentTotal']),
            _smallMetric('异常学生', summary['abnormalStudentCount']),
            _smallMetric('请假冲突', summary['leaveConflictCount']),
            _smallMetric('失败记录', summary['failedRecordCount']),
          ],
        ),
        const SizedBox(height: 12),
        if (classSummary.isNotEmpty) ...[
          Text('班级概览', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in classSummary) _classSummaryCard(item),
          const SizedBox(height: 12),
        ],
        Text('重点关注学生', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (abnormalStudents.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('暂无连续异常学生'),
            ),
          )
        else
          for (final item in abnormalStudents.take(8))
            _abnormalStudentCard(item),
        const SizedBox(height: 12),
        Text('请假冲突', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (leaveConflicts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.event_available_outlined),
              title: Text('暂无请假期间打卡冲突'),
            ),
          )
        else
          for (final item in leaveConflicts.take(8)) _leaveConflictCard(item),
      ],
    );
  }

  Widget _smallMetric(String label, dynamic value) {
    return Chip(
      label: Text('$label：${value ?? 0}'),
      avatar: const Icon(Icons.insights_outlined, size: 18),
    );
  }

  Widget _classSummaryCard(Map<String, dynamic> item) {
    final rate = (item['activityRate'] as num?)?.toDouble() ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text('班级 ${item['classId']}'),
        subtitle: Text(
          '学生 ${item['studentTotal']} 人 / 成功 ${item['successRecordCount']} / 失败 ${item['failedRecordCount']} / 请假 ${item['leaveCount']}',
        ),
        trailing: Text('${rate.toStringAsFixed(1)}%'),
      ),
    );
  }

  Widget _abnormalStudentCard(Map<String, dynamic> item) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
        title: Text('${item['name']} ${item['studentId']}'),
        subtitle: Text(
          '连续异常 ${item['continuousMissingDays']} 天 / 区间缺勤 ${item['missingDays']} 天 / 失败记录 ${item['failedRecordCount']}',
        ),
        trailing: Chip(
          label: Text(item['faceRegistered'] == true ? '已录脸' : '未录脸'),
        ),
      ),
    );
  }

  Widget _leaveConflictCard(Map<String, dynamic> item) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_busy_outlined, color: Colors.redAccent),
        title: Text('${item['name']} ${item['studentId']}'),
        subtitle: Text(
          '请假：${item['leaveStart']} - ${item['leaveEnd']}\n打卡：${item['checkinType']} ${item['checkinTime']}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _rateCard(String title, dynamic value, IconData icon, Color color) {
    final rate = (value as num?)?.toDouble() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${rate.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (rate / 100).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['date']}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _trendLine('查寝', item['dormRate'], item['dormCount']),
            _trendLine('课堂', item['classRate'], item['classCount']),
            _trendLine('实习', item['internRate'], item['internCount']),
          ],
        ),
      ),
    );
  }

  Widget _trendLine(String label, dynamic rateValue, dynamic countValue) {
    final rate = (rateValue as num?)?.toDouble() ?? 0;
    final count = (countValue as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text('${rate.toStringAsFixed(0)}% / $count',
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
