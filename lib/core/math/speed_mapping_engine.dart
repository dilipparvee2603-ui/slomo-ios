import '../models/speed_keyframe.dart';
import 'bezier_curve.dart';

/// Calculation result for a specific output frame in the interpolation pipeline.
class InterpolationFrameSample {
  final int outputFrameIndex;
  final double outputTimestampSeconds;
  final double sourceTimestampSeconds;
  final int sourceFrameAIndex;
  final int sourceFrameBIndex;
  /// Optical flow phase weight alpha in [0.0, 1.0].
  /// 0.0 = exactly frame A, 1.0 = exactly frame B, 0.5 = midpoint synthesized frame.
  final double opticalFlowAlpha;
  /// True if alpha is virtually 0 or 1, meaning we can use the source frame directly.
  final bool isExactSourceFrame;

  const InterpolationFrameSample({
    required this.outputFrameIndex,
    required this.outputTimestampSeconds,
    required this.sourceTimestampSeconds,
    required this.sourceFrameAIndex,
    required this.sourceFrameBIndex,
    required this.opticalFlowAlpha,
    required this.isExactSourceFrame,
  });
}

/// SpeedMappingEngine calculates Premiere Pro-style constant and variable speed mappings,
/// duration changes, output timestamps, and optical-flow intermediate phase allocations.
class SpeedMappingEngine {
  /// Calculate output duration for a constant speed percentage:
  /// Output Duration = Source Duration * 100 / Speed Percentage
  static double calculateConstantOutputDuration({
    required double sourceDurationSeconds,
    required double speedPercent,
  }) {
    if (sourceDurationSeconds <= 0.0) return 0.0;
    final clampedSpeed = speedPercent.clamp(1.0, 100.0);
    return sourceDurationSeconds * (100.0 / clampedSpeed);
  }

  /// Calculate speed percentage from a desired target duration:
  /// Speed Percentage = (Source Duration / Target Duration) * 100
  static double calculateSpeedPercentFromTargetDuration({
    required double sourceDurationSeconds,
    required double targetDurationSeconds,
  }) {
    if (targetDurationSeconds <= 0.0 || sourceDurationSeconds <= 0.0) return 100.0;
    final pct = (sourceDurationSeconds / targetDurationSeconds) * 100.0;
    return pct.clamp(1.0, 100.0);
  }

  /// Calculate slowdown multiplier (e.g., 25% speed -> 4.0x slower)
  static double calculateSlowdownMultiplier(double speedPercent) {
    final clampedSpeed = speedPercent.clamp(1.0, 100.0);
    return 100.0 / clampedSpeed;
  }

  /// Calculate playback speed multiplier (e.g., 25% speed -> 0.25x playback rate)
  static double calculatePlaybackMultiplier(double speedPercent) {
    final clampedSpeed = speedPercent.clamp(1.0, 100.0);
    return clampedSpeed / 100.0;
  }

  /// Calculate expected intermediate output frames per original source frame interval
  /// e.g. 30 FPS source at 25% speed targeting 120 FPS:
  /// (120 / 30) * (100 / 25) = 4 * 4 = 16 frames!
  static double calculateFramesPerSourceInterval({
    required double sourceFps,
    required double outputFps,
    required double speedPercent,
  }) {
    if (sourceFps <= 0.0 || outputFps <= 0.0) return 1.0;
    final slowdown = calculateSlowdownMultiplier(speedPercent);
    return (outputFps / sourceFps) * slowdown;
  }

  /// Total output frames for constant speed export
  static int calculateTotalOutputFrames({
    required double sourceDurationSeconds,
    required double speedPercent,
    required int outputFps,
  }) {
    final outDuration = calculateConstantOutputDuration(
      sourceDurationSeconds: sourceDurationSeconds,
      speedPercent: speedPercent,
    );
    return (outDuration * outputFps).round();
  }

  /// Evaluate instantaneous speed percentage at normalized source time [0, 1]
  /// given a list of speed keyframes.
  static double evaluateSpeedAtSourceNormalized({
    required double normalizedSourceTime,
    required List<SpeedKeyframe> keyframes,
  }) {
    if (keyframes.isEmpty) return 100.0;
    if (keyframes.length == 1) return keyframes.first.speedPercent;

    final sorted = List<SpeedKeyframe>.from(keyframes)
      ..sort((a, b) => a.normalizedTime.compareTo(b.normalizedTime));

    final t = normalizedSourceTime.clamp(0.0, 1.0);

    // Before first keyframe
    if (t <= sorted.first.normalizedTime) {
      return sorted.first.speedPercent;
    }
    // After last keyframe
    if (t >= sorted.last.normalizedTime) {
      return sorted.last.speedPercent;
    }

    // Find bounding keyframes
    for (int i = 0; i < sorted.length - 1; i++) {
      final k0 = sorted[i];
      final k1 = sorted[i + 1];

      if (t >= k0.normalizedTime && t <= k1.normalizedTime) {
        final intervalSpan = k1.normalizedTime - k0.normalizedTime;
        if (intervalSpan <= 1e-6) return k0.speedPercent;

        final localProgress = (t - k0.normalizedTime) / intervalSpan;

        switch (k0.interpolation) {
          case KeyframeInterpolation.hold:
            return k0.speedPercent;

          case KeyframeInterpolation.linear:
            return k0.speedPercent + localProgress * (k1.speedPercent - k0.speedPercent);

          case KeyframeInterpolation.smoothBezier:
            // Construct Bezier curve with control handles
            final p1x = (k0.handleOutX.abs()).clamp(0.0, 1.0);
            final p1y = (k0.handleOutY).clamp(-1.0, 1.0) * 0.5 + 0.5;
            final p2x = (1.0 - k1.handleInX.abs()).clamp(0.0, 1.0);
            final p2y = (k1.handleInY).clamp(-1.0, 1.0) * 0.5 + 0.5;

            final curve = CubicBezierCurve(p1x, p1y, p2x, p2y);
            final factor = curve.transform(localProgress);
            return k0.speedPercent + factor * (k1.speedPercent - k0.speedPercent);
        }
      }
    }

    return 100.0;
  }

  /// Calculates total output duration for a variable speed ramp by integrating
  /// slowdown dt_out = (100 / speed(t_src)) * dt_src across source time.
  static double calculateVariableOutputDuration({
    required double sourceDurationSeconds,
    required List<SpeedKeyframe> keyframes,
    int integrationSteps = 500,
  }) {
    if (sourceDurationSeconds <= 0.0) return 0.0;
    if (keyframes.isEmpty) {
      return sourceDurationSeconds;
    }

    double totalOutputSeconds = 0.0;
    final dt = sourceDurationSeconds / integrationSteps;

    for (int i = 0; i < integrationSteps; i++) {
      final midSrcTime = (i + 0.5) * dt;
      final normalizedSrc = midSrcTime / sourceDurationSeconds;
      final speedAtT = evaluateSpeedAtSourceNormalized(
        normalizedSourceTime: normalizedSrc,
        keyframes: keyframes,
      ).clamp(1.0, 100.0);

      final instantaneousSlowdown = 100.0 / speedAtT;
      totalOutputSeconds += instantaneousSlowdown * dt;
    }

    return totalOutputSeconds;
  }

  /// Precomputes cumulative mapping table for fast O(log N) output-time to source-time lookup.
  static List<MapEntry<double, double>> buildOutputToSourceLUT({
    required double sourceDurationSeconds,
    required List<SpeedKeyframe> keyframes,
    int sampleCount = 1000,
  }) {
    final lut = <MapEntry<double, double>>[];
    if (sourceDurationSeconds <= 0.0) return lut;

    double cumOutputTime = 0.0;
    final dt = sourceDurationSeconds / sampleCount;

    lut.add(const MapEntry(0.0, 0.0));

    for (int i = 0; i < sampleCount; i++) {
      final srcT = (i + 0.5) * dt;
      final normalizedSrc = srcT / sourceDurationSeconds;
      final speedAtT = evaluateSpeedAtSourceNormalized(
        normalizedSourceTime: normalizedSrc,
        keyframes: keyframes,
      ).clamp(1.0, 100.0);

      cumOutputTime += (100.0 / speedAtT) * dt;
      lut.add(MapEntry(cumOutputTime, (i + 1) * dt));
    }

    return lut;
  }

  /// Maps an output timestamp (seconds) back to source video time (seconds) using LUT and interpolation.
  static double mapOutputTimeToSourceTime({
    required double outputTimeSeconds,
    required double totalOutputDuration,
    required double sourceDuration,
    required List<MapEntry<double, double>> lut,
  }) {
    if (outputTimeSeconds <= 0.0 || lut.isEmpty) return 0.0;
    if (outputTimeSeconds >= totalOutputDuration) return sourceDuration;

    // Binary search in cumulative output time
    int low = 0;
    int high = lut.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final entryTime = lut[mid].key;

      if (entryTime < outputTimeSeconds) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final idx = (low - 1).clamp(0, lut.length - 2);
    final e0 = lut[idx];
    final e1 = lut[idx + 1];

    final outDelta = e1.key - e0.key;
    if (outDelta <= 1e-7) return e0.value;

    final ratio = ((outputTimeSeconds - e0.key) / outDelta).clamp(0.0, 1.0);
    return e0.value + ratio * (e1.value - e0.value);
  }

  /// Generates the exact schedule of frame samples required for optical flow synthesis.
  /// Bounded memory generator for output frames.
  static InterpolationFrameSample planFrameSample({
    required int outputFrameIndex,
    required int outputFps,
    required double sourceFps,
    required int totalSourceFrames,
    required double sourceDurationSeconds,
    required double speedPercent,
    List<SpeedKeyframe>? keyframes,
    List<MapEntry<double, double>>? precomputedLUT,
    double? precomputedOutputDuration,
  }) {
    final outputTimestamp = outputFrameIndex / outputFps;

    double sourceTimestamp;
    if (keyframes != null && keyframes.isNotEmpty) {
      final outDuration = precomputedOutputDuration ??
          calculateVariableOutputDuration(
            sourceDurationSeconds: sourceDurationSeconds,
            keyframes: keyframes,
          );
      final lut = precomputedLUT ??
          buildOutputToSourceLUT(
            sourceDurationSeconds: sourceDurationSeconds,
            keyframes: keyframes,
          );
      sourceTimestamp = mapOutputTimeToSourceTime(
        outputTimeSeconds: outputTimestamp,
        totalOutputDuration: outDuration,
        sourceDuration: sourceDurationSeconds,
        lut: lut,
      );
    } else {
      // Constant speed: sourceTimestamp = outputTimestamp * (speedPercent / 100)
      final playbackRate = calculatePlaybackMultiplier(speedPercent);
      sourceTimestamp = (outputTimestamp * playbackRate).clamp(0.0, sourceDurationSeconds);
    }

    // Determine continuous fractional source frame index
    final exactSourceFrame = sourceTimestamp * sourceFps;
    final frameAIndex = exactSourceFrame.floor().clamp(0, totalSourceFrames - 1);
    final frameBIndex = (frameAIndex + 1).clamp(0, totalSourceFrames - 1);

    // Calculate normalized phase alpha between Frame A and Frame B
    double alpha;
    if (frameAIndex == frameBIndex) {
      alpha = 0.0;
    } else {
      alpha = (exactSourceFrame - frameAIndex).clamp(0.0, 1.0);
    }

    final isExact = (alpha < 0.001) || (alpha > 0.999);

    return InterpolationFrameSample(
      outputFrameIndex: outputFrameIndex,
      outputTimestampSeconds: outputTimestamp,
      sourceTimestampSeconds: sourceTimestamp,
      sourceFrameAIndex: frameAIndex,
      sourceFrameBIndex: frameBIndex,
      opticalFlowAlpha: alpha,
      isExactSourceFrame: isExact,
    );
  }
}
