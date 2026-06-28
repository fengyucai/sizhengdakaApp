import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class InternCheckinPage extends StatefulWidget {
  const InternCheckinPage({super.key});

  @override
  State<InternCheckinPage> createState() => _InternCheckinPageState();
}

class _InternCheckinPageState extends State<InternCheckinPage> {
  final _locationService = LocationService();
  final _logCtrl = TextEditingController();
  Position? _position;
  Map<String, dynamic>? _site;
  List<Map<String, dynamic>> _logs = [];
  bool _checking = false;
  String _statusText = '正在获取定位...';

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await ApiService.getInternLogs();
      if (mounted) setState(() => _logs = logs);
    } catch (_) {
      // 日志历史加载失败不影响当日打卡。
    }
  }

  Future<void> _getLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      final site = await ApiService.getBestCheckinSite(
        type: 'INTERNSHIP',
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _site = site;
        _statusText = '定位成功';
      });
    } catch (e) {
      setState(() => _statusText = '定位失败: $e');
    }
  }

  Future<void> _doCheckin() async {
    if (_position == null) return;
    if (_site == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获取到可用实习打卡点，请重新定位'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_logCtrl.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('工作日志至少50字'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() { _checking = true; _statusText = '正在提交...'; });
    try {
      final result = await ApiService.internCheckin(
        lat: _position!.latitude,
        lng: _position!.longitude,
        siteId: _site!['id'] as int,
        logContent: _logCtrl.text.trim(),
      );
      if (mounted) {
        if (result['status'] == 'SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 实习打卡+日志提交成功!'), backgroundColor: Colors.green),
          );
          await _loadLogs();
          if (!mounted) return;
          context.go('/home');
        } else {
          setState(() => _statusText = '提交失败: ${result['message']}');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = '提交失败: 网络错误');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('实习打卡')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 定位状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: _position != null ? Colors.green : Colors.grey, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusText, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (_position != null)
                          Text('${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        if (_site != null) ...[
                          const SizedBox(height: 4),
                          Text(_site!['name']?.toString() ?? '最近实习打卡点',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '距离 ${_site!['distanceMeters']} 米 · ${_site!['inRange'] == true ? '在范围内' : '不在范围内'}',
                            style: TextStyle(
                              color: _site!['inRange'] == true ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 工作日志
            const Text('今日工作日志', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _logCtrl,
              maxLines: 6,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '请描述今日实习内容 (50-300字)\n\n① 今日完成工作\n② 遇到的问题\n③ 明日计划',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // 提交按钮
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _checking || _position == null || _site == null ? null : _doCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _checking
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('提交打卡 + 日志', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('实习日志历史', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                TextButton(onPressed: _loadLogs, child: const Text('刷新')),
              ],
            ),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('暂无历史日志', style: TextStyle(color: Colors.grey))),
              ),
            for (final log in _logs.take(5)) _buildLogCard(log),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    return Card(
      child: ListTile(
        title: Text('${log['workDate'] ?? ''} · ${log['companyName'] ?? ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            if ((log['mentorReview'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('导师评阅：${log['mentorReview']}', style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logCtrl.dispose();
    super.dispose();
  }
}
