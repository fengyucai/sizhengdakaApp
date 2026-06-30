import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';
import '../../services/face_quality_service.dart';
import '../../services/location_service.dart';
import '../face/face_live_capture_page.dart';

class ClassCheckinPage extends StatefulWidget {
  const ClassCheckinPage({super.key});

  @override
  State<ClassCheckinPage> createState() => _ClassCheckinPageState();
}

class _ClassCheckinPageState extends State<ClassCheckinPage> {
  final _locationService = LocationService();
  final _faceCaptureService = FaceCaptureService();

  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _selectedSession;
  Position? _position;
  Map<String, dynamic>? _address;
  String? _faceImage;
  bool _loading = true;
  bool _checking = false;
  String _statusText = '正在加载课堂签到请求...';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _statusText = '正在刷新课堂签到请求...';
      });
    }
    try {
      final sessions = await ApiService.getActiveClassSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _selectedSession = sessions.isNotEmpty ? sessions.first : null;
        _loading = false;
        _statusText = sessions.isEmpty ? '暂无教师发起的课堂签到' : '请选择并完成签到';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = '课堂签到请求加载失败：${_friendlyError(e)}';
      });
    }
  }

  Future<void> _getLocation({bool forceRefresh = false}) async {
    setState(() => _statusText = forceRefresh ? '正在刷新高精度定位...' : '正在获取可用定位...');
    final location = await _locationService.getCurrentLocation(
      forceRefresh: forceRefresh,
      cacheMaxAge: const Duration(minutes: 3),
      cacheMaxAccuracy: 150,
    );
    final pos = location.position;
    Map<String, dynamic>? address;
    if (location.address != null) {
      address = location.address;
    } else {
      try {
        address = await ApiService.reverseGeocode(
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (_) {
        address = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _position = pos;
      _address = address;
      _statusText = pos.accuracy > 200
          ? '定位已获取但精度较低，建议刷新高精度定位后再提交'
          : forceRefresh
              ? '高精度定位已刷新，可提交位置签到'
              : '定位已获取，可提交位置签到';
    });
  }

  Future<void> _captureFace() async {
    setState(() => _statusText = '请完成实时正脸采集...');
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const FaceLiveCapturePage(
          pose: FaceCapturePose.front,
          title: '课堂拍照签到实时采集',
        ),
      ),
    );
    if (!mounted || path == null) return;
    final base64 = await _faceCaptureService.fileToBase64(path);
    if (!mounted || base64 == null) return;
    setState(() {
      _faceImage = base64;
      _statusText = '真人人脸采集通过，可提交拍照签到';
    });
  }

  Future<void> _doCheckin() async {
    if (_checking) return;
    final session = _selectedSession;
    if (session == null) {
      _show('暂无可签到场次', Colors.orange);
      return;
    }
    final mode = '${session['signMode'] ?? 'LOCATION'}';
    if (mode == 'QR') {
      context.push('/checkin/class/scan');
      return;
    }
    if (mode == 'LOCATION' && _position == null) {
      try {
        await _getLocation();
      } catch (e) {
        _show(_friendlyError(e), Colors.red);
        return;
      }
    }
    if (mode == 'PHOTO' && _faceImage == null) {
      _show('请先完成真人人脸采集', Colors.orange);
      return;
    }

    setState(() {
      _checking = true;
      _statusText = '正在提交签到...';
    });
    try {
      final result = await ApiService.classCheckin(
        lat: mode == 'LOCATION' ? _position?.latitude : null,
        lng: mode == 'LOCATION' ? _position?.longitude : null,
        siteId: (session['siteId'] as num?)?.toInt(),
        sessionId: (session['id'] as num).toInt(),
        faceImage: mode == 'PHOTO' ? _faceImage : null,
      );
      if (!mounted) return;
      if (result['status'] == 'SUCCESS') {
        _show('签到成功', Colors.green);
        setState(() {
          _faceImage = null;
          _position = null;
          _address = null;
          _statusText = '签到成功，正在刷新剩余签到请求...';
        });
        await _loadSessions();
      } else {
        final message = result['failReason'] ?? result['message'] ?? '签到失败';
        setState(() => _statusText = '签到失败：$message');
        _show('$message', Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      setState(() => _statusText = '签到失败：$message');
      _show(message, Colors.red);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'MANUAL' => '普通签到',
      'QR' => '二维码签到',
      'LOCATION' => '位置签到',
      'PHOTO' => '拍照签到',
      _ => mode,
    };
  }

  IconData _modeIcon(String mode) {
    return switch (mode) {
      'MANUAL' => Icons.touch_app_outlined,
      'QR' => Icons.qr_code_scanner,
      'LOCATION' => Icons.my_location,
      'PHOTO' => Icons.photo_camera_outlined,
      _ => Icons.event_available,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mode = '${_selectedSession?['signMode'] ?? 'LOCATION'}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('上课签到'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(_modeIcon(mode), size: 72, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text(
                      _selectedSession == null ? '等待教师发起签到' : _modeLabel(mode),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusText, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (mode == 'LOCATION') _buildLocationTools(),
                    if (mode == 'PHOTO') _buildPhotoTools(),
                    if (mode == 'QR') _buildQrTools(),
                    if (mode != 'QR')
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _checking || _selectedSession == null
                              ? null
                              : _doCheckin,
                          child: _checking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(mode == 'MANUAL'
                                  ? '确认普通签到'
                                  : mode == 'LOCATION'
                                      ? '提交位置签到'
                                      : '提交拍照签到'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSessionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPanel() {
    if (_loading) return const LinearProgressIndicator();
    if (_sessions.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.event_busy_outlined),
          title: Text('暂无课堂签到请求'),
          subtitle: Text('教师发起普通、二维码、位置或拍照签到后会显示在这里'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('当前课堂签到', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final session in _sessions)
          Card(
            color: session['id'] == _selectedSession?['id']
                ? Colors.blue.shade50
                : null,
            child: ListTile(
              leading: Icon(_modeIcon('${session['signMode'] ?? 'LOCATION'}')),
              title: Text(session['courseName']?.toString() ?? '课堂签到'),
              subtitle: Text(
                '${_modeLabel('${session['signMode'] ?? 'LOCATION'}')} / ${session['teacherName'] ?? ''}\n'
                '${session['siteName'] ?? ''} ${_shortTime(session['signStartTime'])} - ${_shortTime(session['signEndTime'])}',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(session['active'] == true ? '可签到' : '未开始'),
              ),
              onTap: () => setState(() {
                _selectedSession = session;
                _position = null;
                _address = null;
                _faceImage = null;
                _statusText =
                    '已选择${_modeLabel('${session['signMode'] ?? 'LOCATION'}')}';
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationTools() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _checking
              ? null
              : () async {
                  try {
                    await _getLocation(forceRefresh: false);
                  } catch (e) {
                    _show(_friendlyError(e), Colors.red);
                  }
                },
          icon: const Icon(Icons.my_location),
          label: const Text('快速获取定位'),
        ),
        if (_position != null)
          TextButton.icon(
            onPressed: _checking
                ? null
                : () async {
                    try {
                      await _getLocation(forceRefresh: true);
                    } catch (e) {
                      _show(_friendlyError(e), Colors.red);
                    }
                  },
            icon: const Icon(Icons.gps_fixed),
            label: const Text('刷新高精度定位'),
          ),
        if (_position != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}  精度约 ${_position!.accuracy.toStringAsFixed(0)} 米',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_address != null)
            Text(
              _addressLine(_address!),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPhotoTools() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _checking ? null : _captureFace,
          icon: Icon(_faceImage == null ? Icons.face : Icons.verified_user),
          label: Text(_faceImage == null ? '进行真人人脸采集' : '真人人脸已采集'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildQrTools() {
    return Column(
      children: [
        const Text('请扫描教师端显示的动态二维码完成签到'),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _selectedSession == null
                ? null
                : () => context.push('/checkin/class/scan'),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('打开扫码签到'),
          ),
        ),
      ],
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
    final formatted = (address['formattedAddress'] ?? '').toString();
    if (parts.isEmpty) return formatted;
    return '${parts.join(' ')}${formatted.isEmpty ? '' : '\n$formatted'}';
  }

  String _shortTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 16) return text.substring(5, 16).replaceFirst('T', ' ');
    return text;
  }
}
