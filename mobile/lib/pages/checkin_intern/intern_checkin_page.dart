import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic>? _address;
  List<Map<String, dynamic>> _logs = [];
  bool _checking = false;
  bool _loadingLogs = false;
  String _statusText = '正在获取定位...';
  String? _submitFeedback;
  bool _submitSucceeded = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadLogs();
  }

  Future<bool> _loadLogs() async {
    if (mounted) setState(() => _loadingLogs = true);
    try {
      final logs = await ApiService.getInternLogs();
      if (mounted) setState(() => _logs = logs);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _submitFeedback = '日志历史刷新失败：${_friendlyError(e)}');
      }
      return false;
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _getLocation({bool forceRefresh = false}) async {
    try {
      setState(() =>
          _statusText = forceRefresh ? '正在刷新高精度定位...' : '正在获取定位...');
      final pos =
          await _locationService.getCurrentPosition(forceRefresh: forceRefresh);
      final site = await ApiService.getBestCheckinSite(
        type: 'INTERNSHIP',
        lat: pos.latitude,
        lng: pos.longitude,
      );
      Map<String, dynamic>? address;
      try {
        address = await ApiService.reverseGeocode(
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (_) {
        address = null;
      }
      if (!mounted) return;
      setState(() {
        _position = pos;
        _site = site;
        _address = address;
        _statusText = forceRefresh ? '高精度定位已刷新' : '定位成功';
      });
    } catch (e) {
      setState(() => _statusText = '定位失败: $e');
    }
  }

  Future<void> _doCheckin() async {
    if (_position == null) return;
    if (_site == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('未获取到可用实习打卡点，请重新定位'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_logCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请填写工作日志'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      _checking = true;
      _statusText = '正在提交...';
      _submitFeedback = null;
      _submitSucceeded = false;
    });
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
            const SnackBar(
                content: Text('实习打卡和日志提交成功'), backgroundColor: Colors.green),
          );
          final logsRefreshed = await _loadLogs();
          if (!mounted) return;
          _logCtrl.clear();
          setState(() {
            _statusText = '提交成功';
            _submitFeedback = logsRefreshed
                ? '实习打卡和日志已提交成功，历史记录已刷新。'
                : '实习打卡和日志已提交成功，但日志历史刷新失败，请点“刷新”重试。';
            _submitSucceeded = true;
          });
        } else {
          final message = result['message']?.toString() ?? '提交失败';
          setState(() {
            _statusText = '提交失败';
            _submitFeedback = message;
            _submitSucceeded = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final message = _friendlyError(e);
        setState(() {
          _statusText = '提交失败';
          _submitFeedback = message;
          _submitSucceeded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
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
        title: const Text('实习打卡'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
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
                    Icon(Icons.location_on,
                        color: _position != null ? Colors.green : Colors.grey,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_statusText,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (_position != null)
                            Text(
                                '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)} · 精度约${_position!.accuracy.toStringAsFixed(0)}米',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          if (_address != null) ...[
                            const SizedBox(height: 4),
                            Text(_addressLine(_address!),
                                style: const TextStyle(
                                    color: Colors.blueGrey, fontSize: 12)),
                            if ((_address!['formattedAddress'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text('详细地址：${_address!['formattedAddress']}',
                                  style: const TextStyle(
                                      color: Colors.blueGrey, fontSize: 12)),
                            if ((_address!['semanticDescription'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text('周边：${_address!['semanticDescription']}',
                                  style: const TextStyle(
                                      color: Colors.blueGrey, fontSize: 12)),
                          ],
                          if (_site != null) ...[
                            const SizedBox(height: 4),
                            Text(_site!['name']?.toString() ?? '最近实习打卡点',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              '距离 ${_site!['distanceMeters']} 米 · ${_site!['inRange'] == true ? '在范围内' : '不在范围内'}',
                              style: TextStyle(
                                color: _site!['inRange'] == true
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _checking
                                  ? null
                                  : () => _getLocation(forceRefresh: true),
                              icon: const Icon(Icons.my_location, size: 18),
                              label: const Text('重新定位'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 工作日志
            const Text('今日工作日志',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _logCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                helperText: '建议填写50-300字，便于企业导师和辅导员了解实习情况',
                hintText: '请描述今日实习内容\n\n① 今日完成工作\n② 遇到的问题\n③ 明日计划',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // 提交按钮
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _checking || _position == null || _site == null
                    ? null
                    : _doCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _checking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('提交打卡 + 日志', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (_submitFeedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _submitSucceeded
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: _submitSucceeded
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _submitFeedback!,
                  style: TextStyle(
                    color: _submitSucceeded
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('实习日志历史',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                TextButton(
                  onPressed: _loadingLogs ? null : _loadLogs,
                  child: Text(_loadingLogs ? '刷新中...' : '刷新'),
                ),
              ],
            ),
            if (_loadingLogs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child:
                        Text('暂无历史日志', style: TextStyle(color: Colors.grey))),
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
            Text(log['content'] ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if ((log['mentorReview'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('导师评阅：${log['mentorReview']}',
                  style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  String _addressLine(Map<String, dynamic> address) {
    final parts = [
      address['province'],
      address['city'],
      address['district'],
      address['town'],
      address['street'],
      address['streetNumber'],
    ]
        .map((part) => part?.toString() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? '地址信息：百度地图未返回行政区划' : '地址信息：${parts.join(' ')}';
  }

  @override
  void dispose() {
    _logCtrl.dispose();
    super.dispose();
  }
}
