import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class TeacherAlertsPage extends StatefulWidget {
  const TeacherAlertsPage({super.key});

  @override
  State<TeacherAlertsPage> createState() => _TeacherAlertsPageState();
}

class _TeacherAlertsPageState extends State<TeacherAlertsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _handlingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getManageAlerts();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _handle(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    setState(() => _handlingId = id);
    try {
      await ApiService.handleManageAlert(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预警已处理'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _handlingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((item) => item['handled'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('待处理预警 ($pending)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final handled = item['handled'] == true;
                  final id = (item['id'] as num?)?.toInt();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('${item['title']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              Chip(label: Text(handled ? '已处理' : '待处理')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${item['content']}'),
                          const SizedBox(height: 6),
                          Text('时间：${item['time']}  等级：${item['level']}',
                              style: const TextStyle(color: Colors.grey)),
                          if (!handled) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _handlingId == id
                                    ? null
                                    : () => _handle(item),
                                icon: const Icon(Icons.task_alt_outlined),
                                label: const Text('标记处理'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
