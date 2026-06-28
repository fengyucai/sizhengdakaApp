import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/face_capture_service.dart';

class FaceRegisterPage extends StatefulWidget {
  const FaceRegisterPage({super.key});

  @override
  State<FaceRegisterPage> createState() => _FaceRegisterPageState();
}

class _FaceRegisterPageState extends State<FaceRegisterPage> {
  final _faceCaptureService = FaceCaptureService();
  final List<String?> _imagePaths = List.filled(3, null);
  bool _submitting = false;

  static const _labels = ['正面', '微左', '微右'];

  Future<void> _capture(int index) async {
    final image = await _faceCaptureService.captureFaceFile();
    if (!mounted || image == null) return;
    setState(() => _imagePaths[index] = image.path);
  }

  Future<void> _submit() async {
    final paths = _imagePaths.whereType<String>().toList();
    if (paths.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完成正面、微左、微右三张人脸照片采集')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ApiService.registerFace(paths);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '人脸注册完成'), backgroundColor: Colors.green),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('人脸注册失败，请重新采集后提交'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _imagePaths.whereType<String>().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('人脸注册'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => context.go('/home'),
            child: const Text('稍后', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('完成注册后才能进行查寝人脸打卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('已采集 $completed/3', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: completed / 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _labels.length; i++) ...[
              _buildCaptureTile(i),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_submitting ? '正在提交...' : '提交人脸注册'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureTile(int index) {
    final path = _imagePaths[index];
    final hasImage = path != null;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 64,
            color: Colors.grey.shade100,
            child: hasImage
                ? Image.file(File(path), fit: BoxFit.cover)
                : const Icon(Icons.face_retouching_natural, size: 32, color: Colors.grey),
          ),
        ),
        title: Text(_labels[index], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(hasImage ? '已采集，可重新拍摄' : '点击拍摄${_labels[index]}照片'),
        trailing: IconButton(
          onPressed: _submitting ? null : () => _capture(index),
          icon: Icon(hasImage ? Icons.refresh : Icons.photo_camera_outlined),
          tooltip: hasImage ? '重新拍摄' : '拍摄',
        ),
        onTap: _submitting ? null : () => _capture(index),
      ),
    );
  }
}
