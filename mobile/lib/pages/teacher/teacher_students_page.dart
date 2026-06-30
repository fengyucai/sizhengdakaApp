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
  String? _error;

  List<Map<String, dynamic>> get _filteredItems {
    final keyword = _query.trim().toLowerCase();
    return _items.where((item) {
      final faceRegistered = item['faceRegistered'] == true;
      if (_faceFilter == 'REGISTERED' && !faceRegistered) return false;
      if (_faceFilter == 'MISSING' && faceRegistered) return false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('学生信息 (${_filteredItems.length}/${_items.length})'),
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
                      final item = _filteredItems[index - 1];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((item['name'] ?? '?')
                                .toString()
                                .characters
                                .first),
                          ),
                          title: Text('${item['name']} ${item['studentId']}'),
                          subtitle: Text(
                            '班级ID：${item['classId']}  电话：${item['phone'] == '' ? '未填' : item['phone']}',
                          ),
                          trailing: Chip(
                            label: Text(
                                item['faceRegistered'] == true ? '已录脸' : '未录脸'),
                          ),
                        ),
                      );
                    },
                  ),
      ),
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
