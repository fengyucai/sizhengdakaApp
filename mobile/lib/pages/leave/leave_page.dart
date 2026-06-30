import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _reasonCtrl = TextEditingController();
  final List<Map<String, String>> _types = const [
    {'value': 'SICK', 'label': '病假'},
    {'value': 'PERSONAL', 'label': '事假'},
    {'value': 'ACADEMIC', 'label': '公假/教学活动'},
  ];

  String _leaveType = 'SICK';
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await ApiService.getLeaveRequests();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请假记录加载失败：${_friendlyError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current = start ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startTime = value;
        if (!_endTime.isAfter(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 2));
        }
      } else {
        _endTime = value;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请填写请假原因'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_endTime.isAfter(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('结束时间必须晚于开始时间'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.applyLeave(
        leaveType: _leaveType,
        startTime: _startTime,
        endTime: _endTime,
        reason: reason,
      );
      if (!mounted) return;
      _reasonCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请假申请已提交'), backgroundColor: Colors.green),
      );
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('提交失败：${_friendlyError(e)}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await ApiService.cancelLeave(id);
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('取消失败：${_friendlyError(e)}'),
            backgroundColor: Colors.red),
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
        title: const Text('请假申请'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildApplyCard(),
            const SizedBox(height: 16),
            Text('申请记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator())),
            if (!_loading && _records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child:
                        Text('暂无请假记录', style: TextStyle(color: Colors.grey))),
              ),
            for (final record in _records) _buildRecordCard(record),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('提交申请',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _leaveType,
              decoration: const InputDecoration(
                  labelText: '请假类型', border: OutlineInputBorder()),
              items: _types
                  .map((type) => DropdownMenuItem(
                      value: type['value'], child: Text(type['label']!)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _leaveType = value ?? 'SICK'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildTimeButton(
                        '开始时间', _startTime, () => _pickDateTime(start: true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildTimeButton(
                        '结束时间', _endTime, () => _pickDateTime(start: false))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '请假原因',
                helperText: '建议说明请假事由、去向和联系方式',
                hintText: '请说明请假事由',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? '提交中...' : '提交请假申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, DateTime value, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(_formatDateTime(value), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final status = record['status'] ?? '';
    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(status), color: _statusColor(status)),
        title: Text(
            '${record['typeLabel'] ?? record['type']} · ${record['statusLabel'] ?? status}'),
        subtitle: Text(
            '${record['start']} 至 ${record['end']}\n${record['reason'] ?? ''}',
            maxLines: 3),
        isThreeLine: true,
        trailing: status == 'PENDING'
            ? TextButton(
                onPressed: () => _cancel(record['id'] as int),
                child: const Text('取消'))
            : null,
      ),
    );
  }

  IconData _statusIcon(dynamic status) {
    return switch (status) {
      'APPROVED' => Icons.check_circle_outline,
      'REJECTED' => Icons.highlight_off,
      'CANCELLED' => Icons.remove_circle_outline,
      _ => Icons.hourglass_empty,
    };
  }

  Color _statusColor(dynamic status) {
    return switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'CANCELLED' => Colors.grey,
      _ => Colors.orange,
    };
  }

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.month}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }
}
