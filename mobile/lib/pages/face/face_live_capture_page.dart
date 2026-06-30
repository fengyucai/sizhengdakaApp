import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/face_quality_service.dart';

class FaceLiveCapturePage extends StatefulWidget {
  final FaceCapturePose pose;
  final String title;

  const FaceLiveCapturePage({
    super.key,
    required this.pose,
    required this.title,
  });

  @override
  State<FaceLiveCapturePage> createState() => _FaceLiveCapturePageState();
}

class _FaceLiveCapturePageState extends State<FaceLiveCapturePage> {
  final _qualityService = FaceQualityService();
  CameraController? _controller;
  Timer? _timer;
  bool _initializing = true;
  bool _detecting = false;
  bool _finished = false;
  int _stableFrames = 0;
  String _status = '正在打开前置摄像头...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _status = _instructionText;
      });
      _timer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => _probeCurrentFrame(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _status = '摄像头启动失败：$e';
      });
    }
  }

  Future<void> _probeCurrentFrame() async {
    final controller = _controller;
    if (_finished ||
        _detecting ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    _detecting = true;
    try {
      final image = await controller.takePicture();
      final result =
          await _qualityService.validateFile(image.path, pose: widget.pose);
      if (!mounted || _finished) return;
      if (result.passed) {
        _stableFrames += 1;
        setState(() {
          _status = _stableFrames >= 2 ? '动作确认通过，正在提交当前帧...' : '动作已识别，请保持稳定';
        });
        if (_stableFrames >= 2) {
          _finished = true;
          _timer?.cancel();
          if (mounted) Navigator.of(context).pop(image.path);
        }
      } else {
        _stableFrames = 0;
        setState(() => _status = result.message);
      }
    } catch (e) {
      if (mounted && !_finished) {
        setState(() => _status = '正在重新识别人脸，请保持在取景框内');
      }
    } finally {
      _detecting = false;
    }
  }

  String get _instructionText {
    return switch (widget.pose) {
      FaceCapturePose.front => '请正对摄像头，保持面部清晰',
      FaceCapturePose.turnLeft => '请向左轻微转头，并保持 1 秒',
      FaceCapturePose.turnRight => '请向右轻微转头，并保持 1 秒',
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _qualityService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: _initializing
                    ? const CircularProgressIndicator()
                    : controller == null || !controller.value.isInitialized
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              CameraPreview(controller),
                              Container(
                                width: 250,
                                height: 320,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _stableFrames > 0
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(140),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    _instructionText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _stableFrames > 0 ? Colors.green : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: (_stableFrames / 2).clamp(0, 1).toDouble(),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('取消采集'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
