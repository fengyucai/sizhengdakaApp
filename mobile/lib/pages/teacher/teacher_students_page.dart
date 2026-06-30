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
        title: Text('学生信息 (${_items.length})'),
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
                        label: Text(item['faceRegistered'] == true
                            ? '已录脸'
                            : '未录脸'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
