import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../core/models/video_metadata.dart';
import 'platform_bridge_service.dart';

class VideoImportService {
  final ImagePicker _imagePicker = ImagePicker();
  final PlatformBridgeService _platformBridge;

  VideoImportService({PlatformBridgeService? platformBridge})
      : _platformBridge = platformBridge ?? PlatformBridgeService();

  /// Import video from iOS Photos Gallery
  Future<VideoMetadata?> pickFromGallery() async {
    final XFile? file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 60),
    );

    if (file == null) return null;
    return await _inspectAndValidate(file.path);
  }

  /// Import video from iOS Files app / iCloud Drive
  Future<VideoMetadata?> pickFromFiles() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return null;
    }

    return await _inspectAndValidate(result.files.first.path!);
  }

  /// Inspect and validate video file
  Future<VideoMetadata> _inspectAndValidate(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Selected video file does not exist at $path');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('Selected video file is empty (0 bytes).');
    }

    final metadata = await _platformBridge.inspectVideo(path);
    return metadata;
  }
}
