import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';
import '../../services/location_service.dart';

class ClassCheckinPage extends StatefulWidget {
  const ClassCheckinPage({super.key});

  @override
  State<ClassCheckinPage> createState() => _ClassCheckinPageState();
}

class _ClassCheckinPageState extends State<ClassCheckinPage> {
  final _locationService = LocationService();
  final _faceCaptureService = FaceCaptureService();
  Position? _position;
  bool _checking = false;
  String? _faceImage;
  String _statusText = '正在获取定位...';
  bool _useLocation = true; // true=GPS签到 false=扫码签到

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _position = pos;
        _statusText = '定位成功 — 准备签到';
      });
    } catch (e) {
      setState(() => _statusText = '定位失败: $e');
    }
  }

  Future<void> _doCheckin() async {
    if (_position == null) return;
    setState(() { _checking = true; _statusText = '正在签到...'; });
    try {
      final result = await ApiService.classCheckin(
        lat: _position!.latitude,
        lng: _position!.longitude,
        siteId: 2, // 教室打卡点ID
        faceImage: _faceImage,
      );
      if (mounted) {
        if (result['status'] == 'SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 签到成功!'), backgroundColor: Colors.green),
          );
          context.go('/home');
        } else {
          setState(() => _statusText = '签到失败: ${result['message']}');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = '签到失败: 网络错误');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _captureFace() async {
    final image = await _faceCaptureService.captureFaceBase64();
    if (!mounted) return;
    if (image != null) {
      setState(() {
        _faceImage = image;
        _statusText = '人脸照片已采集 — 准备签到';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上课打卡')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 切换签到方式
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('GPS签到'),
                  selected: _useLocation,
                  onSelected: (_) => setState(() => _useLocation = true),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('扫码签到'),
                  selected: !_useLocation,
                  onSelected: (_) => setState(() => _useLocation = false),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_useLocation) ...[
              Icon(
                _position != null ? Icons.my_location : Icons.location_searching,
                size: 80, color: _position != null ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(_statusText, style: const TextStyle(fontSize: 16)),
              if (_position != null)
                Text('${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _checking ? null : _captureFace,
                icon: Icon(_faceImage != null ? Icons.verified_user : Icons.face),
                label: Text(_faceImage != null ? '已采集人脸' : '拍摄人脸照片'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _checking || _position == null ? null : _doCheckin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: _checking
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('确认签到', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else ...[
              // 扫码区域UI占位
              Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: const Center(child: Icon(Icons.qr_code_scanner, size: 120, color: Colors.grey)),
              ),
              const SizedBox(height: 16),
              const Text('请扫描教师端动态二维码', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/checkin/class/scan'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('打开扫码'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
