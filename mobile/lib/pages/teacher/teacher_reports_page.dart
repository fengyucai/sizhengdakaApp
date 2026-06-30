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
  List<Map<String, dynamic>> _trend = [];
  bool _loading = true;
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
      if (!mounted) return;
      setState(() {
        _weekly = weekly;
        _trend = trend;
        _loading = false;
      });
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
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('周报概览', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _rateCard('查寝周报', _weekly?['dormRate'], Icons.home_outlined,
                      Colors.blue),
                  _rateCard('课堂出勤周报', _weekly?['classRate'],
                      Icons.co_present_outlined, Colors.green),
                  _rateCard('实习日志周报', _weekly?['internRate'],
                      Icons.work_outline, Colors.purple),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('周内记录总数'),
                      trailing: Text('${(_weekly?['recordCount'] as num?)?.toInt() ?? 0} 条'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('出勤趋势', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final item in _trend) _trendCard(item),
                ],
              ),
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
