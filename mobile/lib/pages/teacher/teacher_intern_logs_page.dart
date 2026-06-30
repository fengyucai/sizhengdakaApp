import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import 'review_text_dialog.dart';

class TeacherInternLogsPage extends StatefulWidget {
  const TeacherInternLogsPage({super.key});

  @override
  State<TeacherInternLogsPage> createState() => _TeacherInternLogsPageState();
}

class _TeacherInternLogsPageState extends State<TeacherInternLogsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _submittingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getManageInternLogs();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('实习日志加载失败'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final comment = await _askComment();
    if (comment == null) return;
    if (comment.trim().length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('评阅意见至少 2 个字'), backgroundColor: Colors.orange),
      );
      return;
    }
    final id = (item['id'] as num).toInt();
    setState(() => _submittingId = id);
    try {
      await ApiService.reviewInternLog(id, comment: comment.trim());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评阅已提交'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<String?> _askComment() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const ReviewTextDialog(
        title: '导师评阅',
        hintText: '填写评阅意见',
        helperText: '2-300 字',
        maxLines: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _items.where((item) => item['reviewed'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('实习日志 ($pending)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Icon(Icons.work_history_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无实习日志', style: TextStyle(color: Colors.grey))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildCard(_items[index]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final reviewed = item['reviewed'] == true;
    final id = (item['id'] as num?)?.toInt();
    final submitting = id != null && _submittingId == id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['name'] ?? ''} ${item['studentId'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(reviewed ? '已评阅' : '未评阅',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor:
                      reviewed ? Colors.green.shade50 : Colors.orange.shade50,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('日期：${item['workDate'] ?? ''}'),
            Text('单位：${item['company'] ?? ''}'),
            const SizedBox(height: 8),
            Text('日志：${item['content'] ?? ''}'),
            if ((item['mentorReview'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('评阅：${item['mentorReview']}',
                  style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: submitting ? null : () => _review(item),
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rate_review_outlined),
                label: Text(reviewed ? '修改评阅' : '填写评阅'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
