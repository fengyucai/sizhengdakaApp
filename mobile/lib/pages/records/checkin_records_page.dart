import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CheckinRecordsPage extends StatefulWidget {
  const CheckinRecordsPage({super.key});

  @override
  State<CheckinRecordsPage> createState() => _CheckinRecordsPageState();
}

class _CheckinRecordsPageState extends State<CheckinRecordsPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await ApiService.getCheckinRecords(limit: 50);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appeal(Map<String, dynamic> record) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('异常申诉'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: '请说明定位偏差、人脸识别失败等具体原因，至少10个字',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(ctrl.text.trim()), child: const Text('提交')),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty) return;
    if (reason.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申诉原因至少10个字'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await ApiService.appealCheckinRecord(id: record['id'] as int, reason: reason);
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申诉已提交'), backgroundColor: Colors.green),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申诉提交失败'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('打卡记录')),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Icon(Icons.checklist, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无打卡记录', style: TextStyle(color: Colors.grey))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildRecordCard(_records[index]),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final success = record['status'] == 'SUCCESS';
    final appealStatus = record['appealStatus']?.toString() ?? '';
    final canAppeal = !success && appealStatus != 'PENDING' && appealStatus != 'APPROVED';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(success ? Icons.check_circle : Icons.error_outline, color: success ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${record['typeLabel'] ?? record['type']} · ${_formatTime(record['time'])}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(success ? '成功' : '异常', style: const TextStyle(fontSize: 12)),
                  backgroundColor: success ? Colors.green.shade50 : Colors.red.shade50,
                ),
              ],
            ),
            if ((record['failReason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('失败原因：${record['failReason']}', style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFlag('定位', record['locationPassed'] == true),
                _buildFlag('人脸', record['facePassed'] == true),
                _buildFlag('活体', record['livenessPassed'] == true),
              ],
            ),
            if (appealStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('申诉状态：${_appealLabel(appealStatus)}', style: const TextStyle(color: Colors.blueGrey)),
              if ((record['appealReviewComment'] ?? '').toString().isNotEmpty)
                Text('审核意见：${record['appealReviewComment']}', style: const TextStyle(color: Colors.grey)),
            ],
            if (canAppeal) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _appeal(record),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('提交申诉'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlag(String label, bool ok) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label${ok ? "通过" : "未通过"}', style: const TextStyle(fontSize: 12)),
      avatar: Icon(ok ? Icons.check : Icons.close, size: 16, color: ok ? Colors.green : Colors.red),
    );
  }

  String _appealLabel(String status) {
    return switch (status) {
      'PENDING' => '待审核',
      'APPROVED' => '已通过',
      'REJECTED' => '已驳回',
      _ => status,
    };
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 16) return text.substring(0, 16).replaceFirst('T', ' ');
    return text;
  }
}
