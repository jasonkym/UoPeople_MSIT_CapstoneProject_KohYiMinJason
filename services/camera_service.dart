import 'dart:io';

import 'package:image_picker/image_picker.dart';

abstract class CameraPickerClient {
  Future<XFile?> pickImage({required ImageSource source, int? imageQuality});
}

class ImagePickerClient implements CameraPickerClient {
  ImagePickerClient({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage({required ImageSource source, int? imageQuality}) {
    return _picker.pickImage(source: source, imageQuality: imageQuality);
  }
}

class CameraService {
  static final CameraPickerClient _defaultPickerClient = ImagePickerClient();

  /// Pick an image from the device camera
  static Future<File?> pickFromCamera({
    CameraPickerClient? pickerClient,
  }) async {
    final client = pickerClient ?? _defaultPickerClient;
    try {
      final xFile = await client.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xFile == null) return null;
      return File(xFile.path);
    } catch (e) {
      rethrow;
    }
  }

  /// Pick an image from the device gallery/photo library
  static Future<File?> pickFromGallery({
    CameraPickerClient? pickerClient,
  }) async {
    final client = pickerClient ?? _defaultPickerClient;
    try {
      final xFile = await client.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xFile == null) return null;
      return File(xFile.path);
    } catch (e) {
      rethrow;
    }
  }
}
