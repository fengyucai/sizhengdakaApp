import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FaceCaptureService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> captureFaceFile() {
    return _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 65,
      maxWidth: 900,
    );
  }

  Future<String?> captureFaceBase64() async {
    final image = await captureFaceFile();
    if (image == null) return null;
    return fileToBase64(image.path);
  }

  Future<String?> fileToBase64(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }
}
