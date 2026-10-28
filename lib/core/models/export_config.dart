enum VideoContainer {
  mp4,
  mov,
}

enum VideoCodec {
  h264,
  hevc, // H.265
}

enum OutputResolution {
  source,
  fhd1080p,
  uhd4k,
  hd720p,
}

enum OutputFrameRate {
  fps30(30),
  fps60(60),
  fps120(120);

  final int fps;
  const OutputFrameRate(this.fps);
}

enum OpticalFlowEngineType {
  appleVisionMetal, // Vision VNGenerateOpticalFlowRequest + Metal/CI Warp & Blend
  appleVTFrameProcessor, // VideoToolbox VTFrameProcessor (iOS 16/17+)
}

enum AudioMode {
  retimedPitchPreserved,
  mute,
  originalSpeed,
}

enum BitrateQuality {
  medium(0.75),
  high(1.0),
  ultra(1.5);

  final double multiplier;
  const BitrateQuality(this.multiplier);
}

class ExportConfig {
  final VideoContainer container;
  final VideoCodec codec;
  final OutputResolution resolution;
  final OutputFrameRate frameRate;
  final OpticalFlowEngineType engineType;
  final AudioMode audioMode;
  final BitrateQuality quality;
  final double trimStartSeconds;
  final double trimEndSeconds;

  const ExportConfig({
    this.container = VideoContainer.mp4,
    this.codec = VideoCodec.hevc,
    this.resolution = OutputResolution.source,
    this.frameRate = OutputFrameRate.fps60,
    this.engineType = OpticalFlowEngineType.appleVisionMetal,
    this.audioMode = AudioMode.retimedPitchPreserved,
    this.quality = BitrateQuality.high,
    this.trimStartSeconds = 0.0,
    this.trimEndSeconds = 0.0,
  });

  /// Approximate target bitrate in bits per second based on resolution, fps, codec, and quality multiplier
  int calculateTargetBitrate({
    required int baseWidth,
    required int baseHeight,
  }) {
    // Determine effective dimension
    int w = baseWidth;
    int h = baseHeight;
    switch (resolution) {
      case OutputResolution.hd720p:
        w = 1280;
        h = 720;
        break;
      case OutputResolution.fhd1080p:
        w = 1920;
        h = 1080;
        break;
      case OutputResolution.uhd4k:
        w = 3840;
        h = 2160;
        break;
      case OutputResolution.source:
        break;
    }

    final totalPixels = w * h;
    double baseMbps;
    if (totalPixels >= 3840 * 2160) {
      baseMbps = (codec == VideoCodec.hevc) ? 35.0 : 55.0;
    } else if (totalPixels >= 1920 * 1080) {
      baseMbps = (codec == VideoCodec.hevc) ? 12.0 : 18.0;
    } else {
      baseMbps = (codec == VideoCodec.hevc) ? 6.0 : 9.0;
    }

    // Scale with FPS: 120 FPS needs ~1.6x 60 FPS bitrate, 30 FPS needs ~0.7x
    final fpsScale = (frameRate.fps == 120) ? 1.6 : (frameRate.fps == 60 ? 1.0 : 0.7);
    final finalMbps = baseMbps * fpsScale * quality.multiplier;
    return (finalMbps * 1000 * 1000).round();
  }

  /// Estimated output file size in bytes
  int estimateOutputSizeBytes({
    required double outputDurationSeconds,
    required int baseWidth,
    required int baseHeight,
  }) {
    final videoBps = calculateTargetBitrate(baseWidth: baseWidth, baseHeight: baseHeight);
    final audioBps = (audioMode == AudioMode.mute) ? 0 : 256 * 1000;
    final totalBps = videoBps + audioBps;
    return ((totalBps * outputDurationSeconds) / 8.0).round();
  }

  ExportConfig copyWith({
    VideoContainer? container,
    VideoCodec? codec,
    OutputResolution? resolution,
    OutputFrameRate? frameRate,
    OpticalFlowEngineType? engineType,
    AudioMode? audioMode,
    BitrateQuality? quality,
    double? trimStartSeconds,
    double? trimEndSeconds,
  }) {
    return ExportConfig(
      container: container ?? this.container,
      codec: codec ?? this.codec,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      engineType: engineType ?? this.engineType,
      audioMode: audioMode ?? this.audioMode,
      quality: quality ?? this.quality,
      trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
      trimEndSeconds: trimEndSeconds ?? this.trimEndSeconds,
    );
  }

  Map<String, dynamic> toMap({required int sourceWidth, required int sourceHeight}) => {
    'container': container.name,
    'codec': codec.name,
    'resolution': resolution.name,
    'fps': frameRate.fps,
    'engineType': engineType.name,
    'audioMode': audioMode.name,
    'bitrate': calculateTargetBitrate(baseWidth: sourceWidth, baseHeight: sourceHeight),
    'trimStartSeconds': trimStartSeconds,
    'trimEndSeconds': trimEndSeconds,
  };
}
