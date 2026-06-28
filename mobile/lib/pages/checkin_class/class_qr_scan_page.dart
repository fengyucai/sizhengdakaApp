import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';
import '../../services/location_service.dart';

class ClassQrScanPage extends StatefulWidget {
  const ClassQrScanPage({super.key});

  @override
  State<ClassQrScanPage> createState() => _ClassQrScanPageState();
}

class _ClassQrScanPageState extends State<ClassQrScanPage> {
  final _scannerController = MobileScannerController();
  final _locationService = LocationService();
  final _faceCaptureService = FaceCaptureService();
  bool _submitting = false;
  String? _faceImage;

  Future<void> _submit(String token) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      final result = await ApiService.classScanCheckin(
        qrToken: token,
        lat: pos.latitude,
        lng: pos.longitude,
        faceImage: _faceImage,
      );
      if (!mounted) return;
      if (result['status'] == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 扫码签到成功'), backgroundColor: Colors.green),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('签到失败: ${result['message']}'), backgroundColor: Colors.orange),
        );
        setState(() => _submitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('签到失败，请检查二维码或定位权限'), backgroundColor: Colors.red),
      );
      setState(() => _submitting = false);
    }
  }

  Future<void> _captureFace() async {
    final image = await _faceCaptureService.captureFaceBase64();
    if (!mounted) return;
    if (image != null) setState(() => _faceImage = image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码签到')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
              if (code != null && code.isNotEmpty) {
                _scannerController.stop();
                _submit(code);
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.55),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _submitting ? '正在提交签到...' : '对准教师端动态二维码',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _captureFace,
                      icon: Icon(_faceImage != null ? Icons.verified_user : Icons.face),
                      label: Text(_faceImage != null ? '已采集人脸' : '可选：拍摄人脸'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
