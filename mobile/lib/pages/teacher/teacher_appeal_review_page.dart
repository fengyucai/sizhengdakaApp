import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import 'review_text_dialog.dart';

class TeacherAppealReviewPage extends StatefulWidget {
  const TeacherAppealReviewPage({super.key});

  @override
  State<TeacherAppealReviewPage> createState() =>
      _TeacherAppealReviewPageState();
}

class _TeacherAppealReviewPageState extends State<TeacherAppealReviewPage> {
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
      final items = await ApiService.getManageAppeals();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申诉列表加载失败'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool approved) async {
    final comment =
        await _askComment(approved ? '通过意见' : '驳回原因', '填写审核意见');
    if (comment == null) return;
    if (!mounted) return;
    if (!approved && comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('驳回申诉时请填写原因'), backgroundColor: Colors.orange),
      );
      return;
    }
    final id = (item['id'] as num).toInt();
    setState(() => _submittingId = id);
    try {
      await ApiService.reviewAppeal(id, approved: approved, comment: comment);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '申诉已通过' : '申诉已驳回'),
          backgroundColor: Colors.green,
        ),
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

  Future<String?> _askComment(String title, String hint) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ReviewTextDialog(
        title: title,
        hintText: hint,
      ),
    );
    if (result == null) return null;
    final trimmed = result.trim();
    if (trimmed.isEmpty && title == '通过意见') {
      return '申诉通过，已修正为有效打卡';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('申诉审核 (${_items.length})'),
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
          Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无待审核申诉', style: TextStyle(color: Colors.grey))),
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
                const Chip(label: Text('待审核')),
              ],
            ),
            const SizedBox(height: 8),
            Text('类型：${_typeLabel(item['type'])}'),
            Text('时间：${item['time'] ?? ''}'),
            const SizedBox(height: 8),
            Text('失败原因：${item['failReason'] ?? ''}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 6),
            Text('申诉原因：${item['appealReason'] ?? ''}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : () => _review(item, false),
                    icon: const Icon(Icons.close),
                    label: const Text('驳回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: submitting ? null : () => _review(item, true),
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('通过'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(dynamic value) {
    return switch (value?.toString()) {
      'DORM' => '查寝',
      'CLASS' => '上课',
      'INTERNSHIP' => '实习',
      _ => value?.toString() ?? '',
    };
  }
}
