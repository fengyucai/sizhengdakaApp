import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import 'review_text_dialog.dart';

class TeacherLeaveApprovalPage extends StatefulWidget {
  const TeacherLeaveApprovalPage({super.key});

  @override
  State<TeacherLeaveApprovalPage> createState() =>
      _TeacherLeaveApprovalPageState();
}

class _TeacherLeaveApprovalPageState extends State<TeacherLeaveApprovalPage> {
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
      final items = await ApiService.getManageLeaves();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请假审批列表加载失败'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool approved) async {
    final comment = await _askComment(approved ? '审批意见' : '驳回原因',
        approved ? '同意' : '请说明驳回原因');
    if (comment == null) return;
    if (!mounted) return;
    if (!approved && comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('驳回请假时请填写原因'), backgroundColor: Colors.orange),
      );
      return;
    }
    final id = (item['id'] as num).toInt();
    setState(() => _submittingId = id);
    try {
      if (approved) {
        await ApiService.approveLeave(id, comment: comment);
      } else {
        await ApiService.rejectLeave(id, comment: comment);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '请假申请已批准' : '请假申请已驳回'),
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
        initialValue: title == '审批意见' ? '同意' : '',
      ),
    );
    if (result == null) return null;
    return result.isEmpty && title == '审批意见' ? '同意' : result;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _items.where((item) => item['status'] == 'PENDING').length;
    return Scaffold(
      appBar: AppBar(
        title: Text('请假审批 ($pendingCount)'),
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
          Icon(Icons.event_available_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无请假申请', style: TextStyle(color: Colors.grey))),
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
    final status = item['status']?.toString() ?? '';
    final pending = status == 'PENDING';
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
                  label: Text(_statusLabel(status),
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('类型：${_typeLabel(item['type'])}'),
            Text('时间：${item['start'] ?? ''} 至 ${item['end'] ?? ''}'),
            const SizedBox(height: 8),
            Text('原因：${item['reason'] ?? ''}'),
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          submitting ? null : () => _review(item, false),
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
                      label: const Text('批准'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(dynamic value) {
    return switch (value?.toString()) {
      'SICK' => '病假',
      'PERSONAL' => '事假',
      'ACADEMIC' => '公假/教学活动',
      _ => value?.toString() ?? '',
    };
  }

  String _statusLabel(String value) {
    return switch (value) {
      'APPROVED' => '已批准',
      'REJECTED' => '已驳回',
      'CANCELLED' => '已取消',
      _ => '待审批',
    };
  }

  Color _statusColor(String value) {
    return switch (value) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'CANCELLED' => Colors.grey,
      _ => Colors.orange,
    };
  }
}
