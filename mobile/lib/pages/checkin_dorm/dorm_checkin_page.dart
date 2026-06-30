import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';
import '../../services/face_quality_service.dart';
import '../../services/location_service.dart';
import '../face/face_live_capture_page.dart';

class DormCheckinPage extends StatefulWidget {
  const DormCheckinPage({super.key});

  @override
  State<DormCheckinPage> createState() => _DormCheckinPageState();
}

class _DormCheckinPageState extends State<DormCheckinPage> {
  final _locationService = LocationService();
  final _faceCaptureService = FaceCaptureService();
  Position? _position;
  Map<String, dynamic>? _site;
  Map<String, dynamic>? _address;
  bool _checking = false;
  bool _faceRegistered = true;
  String? _faceImage;
  String _statusText = '正在获取定位...';

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
    _getLocation();
  }

  Future<void> _checkFaceStatus() async {
    try {
      final faceStatus = await ApiService.getFaceStatus();
      if (!mounted) return;
      final registered = faceStatus['faceRegistered'] == true;
      setState(() {
        _faceRegistered = registered;
        if (!registered) _statusText = '请先完成人脸注册';
      });
    } catch (_) {
      // 后端查寝接口会再次校验人脸注册状态，这里只做前端引导。
    }
  }

  Future<void> _getLocation({bool forceRefresh = false}) async {
    try {
      setState(() => _statusText = forceRefresh ? '正在刷新高精度定位...' : '正在获取定位...');
      final pos =
          await _locationService.getCurrentPosition(forceRefresh: forceRefresh);
      if (!mounted) return;
      final site = await ApiService.getBestCheckinSite(
        type: 'DORM',
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
        if (_faceRegistered) {
          _statusText = forceRefresh ? '高精度定位已刷新' : '定位成功，可以进行实时人脸验证';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = '定位失败: $e');
    }
  }

  Future<void> _captureFace() async {
    setState(() => _statusText = '请完成实时正脸采集...');
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const FaceLiveCapturePage(
          pose: FaceCapturePose.front,
          title: '查寝实时人脸采集',
        ),
      ),
    );
    if (!mounted || path == null) return;
    final base64 = await _faceCaptureService.fileToBase64(path);
    if (!mounted || base64 == null) return;
    setState(() {
      _faceImage = base64;
      _statusText = '真人人脸采集通过，可以打卡';
    });
  }

  Future<void> _doCheckin() async {
    if (_position == null) return;
    if (_site == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('未获取到可用查寝打卡点，请重新定位'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_faceRegistered) {
      context.push('/face/register');
      return;
    }
    if (_faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请先完成真人人脸采集'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _checking = true;
      _statusText = '正在打卡...';
    });
    try {
      final result = await ApiService.dormCheckin(
        lat: _position!.latitude,
        lng: _position!.longitude,
        siteId: _site!['id'] as int,
        faceImage: _faceImage,
      );
      if (!mounted) return;
      if (result['status'] == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打卡成功'), backgroundColor: Colors.green),
        );
        context.go('/home');
      } else {
        final message =
            result['failReason'] ?? result['message'] ?? '请检查定位范围或人脸状态';
        setState(() => _statusText = '打卡失败: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = _friendlyError(e);
        setState(() => _statusText = '打卡失败: $message');
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
        title: const Text('查寝打卡'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _position != null
                    ? Icons.location_on
                    : Icons.location_searching,
                size: 80,
                color: _position != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(_statusText,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center),
              if (!_faceRegistered) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/face/register'),
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text('去注册人脸'),
                ),
              ],
              const SizedBox(height: 8),
              if (_position != null)
                Text(
                  '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)} · 精度约${_position!.accuracy.toStringAsFixed(0)}米',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              if (_site != null) ...[
                const SizedBox(height: 8),
                _buildSiteInfo(),
              ],
              const SizedBox(height: 32),
              InkWell(
                onTap: _checking || !_faceRegistered ? null : _captureFace,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: _faceImage != null
                            ? Colors.green
                            : Colors.grey.shade300,
                        width: 3),
                    color: _faceImage != null
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                  ),
                  child: Center(
                    child: Icon(
                      _faceImage != null ? Icons.verified_user : Icons.face,
                      size: 80,
                      color: _faceImage != null ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_faceImage != null ? '真人人脸已采集' : '点击进行真人人脸采集',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _checking || _position == null || _site == null
                      ? null
                      : _doCheckin,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: _checking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('确认打卡', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                  onPressed:
                      _checking ? null : () => _getLocation(forceRefresh: true),
                  child: const Text('重新定位')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteInfo() {
    final inRange = _site?['inRange'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: inRange ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_site?['name']?.toString() ?? '最近打卡点',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '距离 ${_site?['distanceMeters']} 米 · ${inRange ? '在范围内' : '不在范围内'}',
            style: TextStyle(
                color: inRange ? Colors.green : Colors.orange, fontSize: 12),
          ),
          if (_address != null) ...[
            const SizedBox(height: 4),
            Text(_addressLine(_address!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            if ((_address!['formattedAddress'] ?? '').toString().isNotEmpty)
              Text('详细地址：${_address!['formattedAddress']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ],
        ],
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
    return parts.isEmpty ? '地址信息：百度地图未返回行政区划' : parts.join(' ');
  }
}
