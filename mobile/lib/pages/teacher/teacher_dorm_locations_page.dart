import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class TeacherDormLocationsPage extends StatefulWidget {
  const TeacherDormLocationsPage({super.key});

  @override
  State<TeacherDormLocationsPage> createState() =>
      _TeacherDormLocationsPageState();
}

class _TeacherDormLocationsPageState extends State<TeacherDormLocationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getDormTodayLocations();
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
        title: Text('查寝位置核验 (${_items.length})'),
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
          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('今日暂无查寝打卡记录')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        final ok = item['locationPassed'] == true &&
            item['facePassed'] == true &&
            item['livenessPassed'] == true;
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
                        '${item['name']} ${item['studentId']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Chip(
                      label: Text(ok ? '可信' : '需核验'),
                      backgroundColor:
                          ok ? Colors.green.shade50 : Colors.orange.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('时间：${item['time']}'),
                Text('打卡点：${item['siteName']}'),
                Text('学生位置：${item['latitude']}, ${item['longitude']}'),
                Text('打卡点位置：${item['siteLatitude']}, ${item['siteLongitude']}'),
                Text('距离：${item['distanceMeters']} 米 / 半径 ${item['radiusMeters']} 米'),
                Text('设备：${item['deviceInfo'] == '' ? '未上报' : item['deviceInfo']}'),
                Text('IP：${item['ipAddress'] == '' ? '未记录' : item['ipAddress']}'),
                if ((item['failReason'] ?? '').toString().isNotEmpty)
                  Text('异常：${item['failReason']}',
                      style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }
}
