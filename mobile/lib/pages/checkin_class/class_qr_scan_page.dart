import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';

class ClassQrScanPage extends StatefulWidget {
  const ClassQrScanPage({super.key});

  @override
  State<ClassQrScanPage> createState() => _ClassQrScanPageState();
}

class _ClassQrScanPageState extends State<ClassQrScanPage> {
  final _scannerController = MobileScannerController();
  final _locationService = LocationService();
  bool _submitting = false;

  Future<void> _submit(String token) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      double? lat;
      double? lng;
      try {
        final pos = await _locationService.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        lat = null;
        lng = null;
      }
      final result = await ApiService.classScanCheckin(
        qrToken: token,
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      if (result['status'] == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('扫码签到成功'), backgroundColor: Colors.green),
        );
        context.go('/home');
      } else {
        _showFailure('${result['failReason'] ?? result['message'] ?? '请重试'}');
      }
    } catch (e) {
      if (!mounted) return;
      _showFailure(_friendlyError(e));
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('签到失败：$message'), backgroundColor: Colors.red),
    );
    setState(() => _submitting = false);
    _scannerController.start();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码签到'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/checkin/class'),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final code = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              if (code != null && code.isNotEmpty) {
                _scannerController.stop();
                _submit(code);
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.58),
              child: SafeArea(
                child: Text(
                  _submitting ? '正在提交签到...' : '对准教师端动态二维码',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
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
