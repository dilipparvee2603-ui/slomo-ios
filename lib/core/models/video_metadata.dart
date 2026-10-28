/// Video metadata information inspected from the source media file.
class VideoMetadata {
  final String path;
  final String fileName;
  final int width;
  final int height;
  final double fps;
  final double durationSeconds;
  final int totalFrames;
  final String codec;
  final bool hasAudio;
  final int audioChannels;
  final int audioSampleRate;
  final bool isHDR;
  final String colorPrimaries;
  final int fileSizeBytes;
  final int orientationDegrees;

  const VideoMetadata({
    required this.path,
    required this.fileName,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationSeconds,
    required this.totalFrames,
    required this.codec,
    required this.hasAudio,
    this.audioChannels = 2,
    this.audioSampleRate = 48000,
    this.isHDR = false,
    this.colorPrimaries = 'BT.709',
    this.fileSizeBytes = 0,
    this.orientationDegrees = 0,
  });

  /// Effective display width considering orientation (90 or 270 deg rotations)
  int get displayWidth => (orientationDegrees == 90 || orientationDegrees == 270) ? height : width;

  /// Effective display height considering orientation (90 or 270 deg rotations)
  int get displayHeight => (orientationDegrees == 90 || orientationDegrees == 270) ? width : height;

  /// Human-readable aspect ratio
  String get aspectRatioString {
    final w = displayWidth;
    final h = displayHeight;
    if (h == 0) return '16:9';
    final ratio = w / h;
    if ((ratio - 16 / 9).abs() < 0.05) return '16:9';
    if ((ratio - 9 / 16).abs() < 0.05) return '9:16';
    if ((ratio - 4 / 3).abs() < 0.05) return '4:3';
    if ((ratio - 1.0).abs() < 0.05) return '1:1';
    return '${ratio.toStringAsFixed(2)}:1';
  }

  /// Formatted duration string HH:MM:SS.ms
  String get formattedDuration {
    final totalSeconds = durationSeconds.floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final millis = ((durationSeconds - totalSeconds) * 100).round();
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
  }

  /// Formatted file size string (MB / GB)
  String get formattedFileSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Map<String, dynamic> toMap() => {
    'path': path,
    'fileName': fileName,
    'width': width,
    'height': height,
    'fps': fps,
    'durationSeconds': durationSeconds,
    'totalFrames': totalFrames,
    'codec': codec,
    'hasAudio': hasAudio,
    'audioChannels': audioChannels,
    'audioSampleRate': audioSampleRate,
    'isHDR': isHDR,
    'colorPrimaries': colorPrimaries,
    'fileSizeBytes': fileSizeBytes,
    'orientationDegrees': orientationDegrees,
  };

  factory VideoMetadata.fromMap(Map<String, dynamic> map) {
    return VideoMetadata(
      path: map['path'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 1920,
      height: (map['height'] as num?)?.toInt() ?? 1080,
      fps: (map['fps'] as num?)?.toDouble() ?? 30.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      totalFrames: (map['totalFrames'] as num?)?.toInt() ?? 0,
      codec: map['codec'] as String? ?? 'H.264',
      hasAudio: map['hasAudio'] as bool? ?? false,
      audioChannels: (map['audioChannels'] as num?)?.toInt() ?? 2,
      audioSampleRate: (map['audioSampleRate'] as num?)?.toInt() ?? 48000,
      isHDR: map['isHDR'] as bool? ?? false,
      colorPrimaries: map['colorPrimaries'] as String? ?? 'BT.709',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      orientationDegrees: (map['orientationDegrees'] as num?)?.toInt() ?? 0,
    );
  }
}
