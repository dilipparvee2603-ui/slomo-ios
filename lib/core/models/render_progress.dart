enum RenderStatus {
  idle,
  preparing,
  extractingFrames,
  computingOpticalFlow,
  synthesizingFrames,
  retimingAudio,
  encodingOutput,
  completed,
  cancelled,
  error,
}

class RenderProgress {
  final RenderStatus status;
  final double progress; // 0.0 to 1.0
  final int currentFrame;
  final int totalFrames;
  final double fpsProcessing;
  final double elapsedSeconds;
  final double etaSeconds;
  final String statusMessage;
  final String? outputPath;
  final String? errorMessage;

  const RenderProgress({
    this.status = RenderStatus.idle,
    this.progress = 0.0,
    this.currentFrame = 0,
    this.totalFrames = 0,
    this.fpsProcessing = 0.0,
    this.elapsedSeconds = 0.0,
    this.etaSeconds = 0.0,
    this.statusMessage = '',
    this.outputPath,
    this.errorMessage,
  });

  bool get isRunning =>
      status == RenderStatus.preparing ||
      status == RenderStatus.extractingFrames ||
      status == RenderStatus.computingOpticalFlow ||
      status == RenderStatus.synthesizingFrames ||
      status == RenderStatus.retimingAudio ||
      status == RenderStatus.encodingOutput;

  String get formattedEta {
    if (etaSeconds <= 0 || etaSeconds.isInfinite || etaSeconds.isNaN) return '--:--';
    final totalSec = etaSeconds.round();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  factory RenderProgress.fromMap(Map<String, dynamic> map) {
    RenderStatus status = RenderStatus.idle;
    final statusStr = map['status'] as String? ?? 'idle';
    for (final s in RenderStatus.values) {
      if (s.name == statusStr) {
        status = s;
        break;
      }
    }

    return RenderProgress(
      status: status,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      currentFrame: (map['currentFrame'] as num?)?.toInt() ?? 0,
      totalFrames: (map['totalFrames'] as num?)?.toInt() ?? 0,
      fpsProcessing: (map['fpsProcessing'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: (map['elapsedSeconds'] as num?)?.toDouble() ?? 0.0,
      etaSeconds: (map['etaSeconds'] as num?)?.toDouble() ?? 0.0,
      statusMessage: map['statusMessage'] as String? ?? '',
      outputPath: map['outputPath'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
