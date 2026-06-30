import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'face_live_capture_page.dart';
import '../../services/face_quality_service.dart';

class FaceRegisterPage extends StatefulWidget {
  const FaceRegisterPage({super.key});

  @override
  State<FaceRegisterPage> createState() => _FaceRegisterPageState();
}

class _FaceRegisterPageState extends State<FaceRegisterPage> {
  final List<String?> _imagePaths = List.filled(3, null);
  bool _submitting = false;

  static const _labels = ['正面', '微左', '微右'];
  static const _poses = [
    FaceCapturePose.front,
    FaceCapturePose.turnLeft,
    FaceCapturePose.turnRight,
  ];

  Future<void> _capture(int index) async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FaceLiveCapturePage(
          pose: _poses[index],
          title: '${_labels[index]}实时采集',
        ),
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      _imagePaths[index] = path;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${_labels[index]}采集通过'),
          backgroundColor: Colors.green),
    );
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
        SnackBar(
            content: Text(result['message'] ?? '人脸注册完成'),
            backgroundColor: Colors.green),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('人脸注册失败，请重新采集后提交'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logoutToLogin() async {
    if (_submitting) return;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出人脸注册'),
        content: const Text('将退出当前账号并返回登录页，之后可重新登录或切换其他账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await context.read<AuthService>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final completed = _imagePaths.whereType<String>().length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _logoutToLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('人脸注册'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '返回登录',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _submitting ? null : _logoutToLogin,
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _logoutToLogin,
              child: const Text('切换账号'),
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
                      const Text('请先完成真人动作人脸采集',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text(
                          '当前使用前置摄像头实时检测正脸、左转、右转动作，动作稳定后自动截取合格帧并提交腾讯云人脸库比对。'),
                      const SizedBox(height: 8),
                      Text('已采集 $completed/3',
                          style: TextStyle(color: Colors.grey.shade700)),
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
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_submitting ? '正在提交...' : '提交腾讯云人脸注册'),
                ),
              ),
            ],
          ),
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
                : const Icon(Icons.face_retouching_natural,
                    size: 32, color: Colors.grey),
          ),
        ),
        title: Text(_labels[index],
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Text(hasImage ? '动作校验通过，可重新采集' : '按要求完成${_labels[index]}动作采集'),
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
