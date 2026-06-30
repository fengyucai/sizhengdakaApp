import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({super.key});

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _query = '';
  String _faceFilter = 'ALL';
  String _statusFilter = 'ALL';
  String? _error;

  List<Map<String, dynamic>> get _filteredItems {
    final keyword = _query.trim().toLowerCase();
    return _items.where((item) {
      final faceRegistered = item['faceRegistered'] == true;
      final status = _studentStatus(item);
      if (_faceFilter == 'REGISTERED' && !faceRegistered) return false;
      if (_faceFilter == 'MISSING' && faceRegistered) return false;
      if (_statusFilter != 'ALL' && status != _statusFilter) return false;
      if (keyword.isEmpty) return true;
      return [
        item['name'],
        item['studentId'],
        item['phone'],
        item['classId'],
      ].any((value) => value.toString().toLowerCase().contains(keyword));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getManageStudents();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  String _studentStatus(Map<String, dynamic> item) =>
      (item['status'] ?? 'ACTIVE').toString().toUpperCase();

  int _studentId(Map<String, dynamic> item) => (item['id'] as num).toInt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('学生账号 (${_filteredItems.length}/${_items.length})'),
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
            : _error != null
                ? _errorState()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredItems.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) return _filterPanel();
                      return _studentCard(_filteredItems[index - 1]);
                    },
                  ),
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> item) {
    final status = _studentStatus(item);
    final suspended = status == 'SUSPENDED';
    final abnormalCount =
        (item['recentAbnormalCount'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                suspended ? Colors.grey.shade300 : Colors.blue.shade100,
            child: Text((item['name'] ?? '?').toString().characters.first),
          ),
          title: Text('${item['name']} ${item['studentId']}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '班级ID：${item['classId']}  电话：${item['phone'] == '' ? '未填' : item['phone']}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _statusChip(
                    item['faceRegistered'] == true ? '已录脸' : '未录脸',
                    item['faceRegistered'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  _statusChip(
                    suspended ? '已停用' : '正常',
                    suspended ? Colors.grey : Colors.blue,
                  ),
                  if (abnormalCount > 0)
                    _statusChip('近30天异常 $abnormalCount', Colors.red),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: '账号操作',
            onSelected: (value) => _handleAction(value, item),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'abnormal',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('查看异常记录'),
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_reset),
                  title: Text('重置密码'),
                ),
              ),
              PopupMenuItem(
                value: suspended ? 'activate' : 'suspend',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    suspended
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                  ),
                  title: Text(suspended ? '恢复账号' : '停用账号'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String text, MaterialColor color) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.shade50,
      side: BorderSide(color: color.shade200),
    );
  }

  Widget _filterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: '搜索姓名、学号、电话或班级',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ALL', label: Text('全部')),
            ButtonSegment(value: 'REGISTERED', label: Text('已录脸')),
            ButtonSegment(value: 'MISSING', label: Text('未录脸')),
          ],
          selected: {_faceFilter},
          onSelectionChanged: (value) =>
              setState(() => _faceFilter = value.first),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ALL', label: Text('全部账号')),
            ButtonSegment(value: 'ACTIVE', label: Text('正常')),
            ButtonSegment(value: 'SUSPENDED', label: Text('停用')),
          ],
          selected: {_statusFilter},
          onSelectionChanged: (value) =>
              setState(() => _statusFilter = value.first),
        ),
        if (_filteredItems.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.search_off_outlined),
              title: Text('没有匹配的学生'),
              subtitle: Text('可以调整搜索关键词或筛选条件'),
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(String action, Map<String, dynamic> item) async {
    switch (action) {
      case 'abnormal':
        await _showAbnormalRecords(item);
        break;
      case 'reset':
        await _resetPassword(item);
        break;
      case 'activate':
        await _updateStatus(item, 'ACTIVE');
        break;
      case 'suspend':
        await _updateStatus(item, 'SUSPENDED');
        break;
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> item) async {
    final confirmed = await _confirm(
      title: '重置密码',
      content: '确认将 ${item['name']} 的密码重置为 123456？',
    );
    if (confirmed != true) return;
    await _runStudentAction(
      () => ApiService.resetStudentPassword(_studentId(item)),
      success: '已重置为默认密码 123456',
    );
  }

  Future<void> _updateStatus(
      Map<String, dynamic> item, String nextStatus) async {
    final suspended = nextStatus == 'SUSPENDED';
    final confirmed = await _confirm(
      title: suspended ? '停用账号' : '恢复账号',
      content: suspended
          ? '停用后 ${item['name']} 将无法登录。确认继续？'
          : '确认恢复 ${item['name']} 的登录权限？',
    );
    if (confirmed != true) return;
    await _runStudentAction(
      () => ApiService.updateStudentStatus(_studentId(item), nextStatus),
      success: suspended ? '账号已停用' : '账号已恢复',
    );
  }

  Future<void> _runStudentAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbnormalRecords(Map<String, dynamic> item) async {
    try {
      final records =
          await ApiService.getStudentAbnormalRecords(_studentId(item));
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: records.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('近期没有异常记录'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text('${record['type']} · ${record['status']}'),
                      subtitle: Text(
                        '${record['time']}\n${record['failReason'] == '' ? record['appealReason'] : record['failReason']}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
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
}
