import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceCapturePose {
  front,
  turnLeft,
  turnRight,
}

class FaceQualityResult {
  final bool passed;
  final String message;
  final double? yaw;
  final double? roll;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  const FaceQualityResult({
    required this.passed,
    required this.message,
    this.yaw,
    this.roll,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });
}

class FaceQualityService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      enableLandmarks: true,
      minFaceSize: 0.18,
    ),
  );

  Future<FaceQualityResult> validateFile(
    String path, {
    FaceCapturePose pose = FaceCapturePose.front,
  }) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) {
      return const FaceQualityResult(
        passed: false,
        message: '未检测到清晰人脸，请使用前置摄像头重新采集',
      );
    }
    if (faces.length > 1) {
      return const FaceQualityResult(
        passed: false,
        message: '画面中存在多张人脸，请确保只有本人入镜',
      );
    }

    final face = faces.first;
    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (roll.abs() > 18) {
      return FaceQualityResult(
        passed: false,
        message: '请保持手机和头部稳定，不要明显歪头',
        yaw: yaw,
        roll: roll,
        leftEyeOpenProbability: leftEye,
        rightEyeOpenProbability: rightEye,
      );
    }

    if (leftEye != null &&
        rightEye != null &&
        (leftEye < 0.35 || rightEye < 0.35)) {
      return FaceQualityResult(
        passed: false,
        message: '请睁眼面对摄像头后重新采集',
        yaw: yaw,
        roll: roll,
        leftEyeOpenProbability: leftEye,
        rightEyeOpenProbability: rightEye,
      );
    }

    final posePassed = switch (pose) {
      FaceCapturePose.front => yaw.abs() <= 15,
      FaceCapturePose.turnLeft => yaw <= -10,
      FaceCapturePose.turnRight => yaw >= 10,
    };

    if (!posePassed) {
      return FaceQualityResult(
        passed: false,
        message: switch (pose) {
          FaceCapturePose.front => '请正对摄像头采集正面人脸',
          FaceCapturePose.turnLeft => '请按要求向左轻微转头后采集',
          FaceCapturePose.turnRight => '请按要求向右轻微转头后采集',
        },
        yaw: yaw,
        roll: roll,
        leftEyeOpenProbability: leftEye,
        rightEyeOpenProbability: rightEye,
      );
    }

    return FaceQualityResult(
      passed: true,
      message: '真人动作采集校验通过',
      yaw: yaw,
      roll: roll,
      leftEyeOpenProbability: leftEye,
      rightEyeOpenProbability: rightEye,
    );
  }

  Future<void> close() => _detector.close();
}
