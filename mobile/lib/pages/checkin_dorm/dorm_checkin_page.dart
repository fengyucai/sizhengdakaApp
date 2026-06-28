import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';
import '../../services/location_service.dart';

class DormCheckinPage extends StatefulWidget {
  const DormCheckinPage({super.key});

  @override
  State<DormCheckinPage> createState() => _DormCheckinPageState();
}

class _DormCheckinPageState extends State<DormCheckinPage> {
  final _locationService = LocationService();
  final _faceCaptureService = FaceCaptureService();
  Position? _position;
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
      // 后端查寝接口仍会兜底校验，这里只做前端引导。
    }
  }

  Future<void> _getLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = pos;
        if (_faceRegistered) _statusText = '定位成功，可以采集人脸';
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = '定位失败: $e');
    }
  }

  Future<void> _captureFace() async {
    final image = await _faceCaptureService.captureFaceBase64();
    if (!mounted || image == null) return;
    setState(() {
      _faceImage = image;
      _statusText = '人脸照片已采集，可以打卡';
    });
  }

  Future<void> _doCheckin() async {
    if (_position == null) return;
    if (!_faceRegistered) {
      context.go('/face/register');
      return;
    }
    if (_faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先拍摄实时人脸照片'), backgroundColor: Colors.orange),
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
        siteId: 1,
        faceImage: _faceImage,
      );
      if (!mounted) return;
      if (result['status'] == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打卡成功'), backgroundColor: Colors.green),
        );
        context.go('/home');
      } else {
        setState(() => _statusText = '打卡失败: ${result['failReason'] ?? result['message'] ?? '请重试'}');
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = '打卡失败，请检查网络或人脸注册状态');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('查寝打卡')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _position != null ? Icons.location_on : Icons.location_searching,
                size: 80,
                color: _position != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(_statusText, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              if (!_faceRegistered) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/face/register'),
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text('去注册人脸'),
                ),
              ],
              const SizedBox(height: 8),
              if (_position != null)
                Text(
                  '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              const SizedBox(height: 32),
              InkWell(
                onTap: _checking || !_faceRegistered ? null : _captureFace,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: _faceImage != null ? Colors.green : Colors.grey.shade300, width: 3),
                    color: _faceImage != null ? Colors.green.shade50 : Colors.grey.shade100,
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
              Text(_faceImage != null ? '人脸已采集' : '点击拍摄实时人脸', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _checking || _position == null ? null : _doCheckin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _checking
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('确认打卡', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _getLocation, child: const Text('重新定位')),
            ],
          ),
        ),
      ),
    );
  }
}
