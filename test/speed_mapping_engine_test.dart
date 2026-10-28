import 'package:flutter_test/flutter_test.dart';
import 'package:slomo_creator_pro/core/math/bezier_curve.dart';
import 'package:slomo_creator_pro/core/math/speed_mapping_engine.dart';
import 'package:slomo_creator_pro/core/models/speed_keyframe.dart';

void main() {
  group('SpeedMappingEngine - Constant Speed Percentage & Durations', () {
    test('Premiere Pro speed percentage to duration calculation', () {
      const sourceDuration = 10.0; // 10 seconds

      // 100% = 10s (normal speed)
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 100.0,
        ),
        closeTo(10.0, 0.001),
      );

      // 75% = 1.33x slower -> 13.333s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 75.0,
        ),
        closeTo(13.333, 0.005),
      );

      // 50% = 2x slower -> 20s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 50.0,
        ),
        closeTo(20.0, 0.001),
      );

      // 40% = 2.5x slower -> 25s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 40.0,
        ),
        closeTo(25.0, 0.001),
      );

      // 25% = 4x slower -> 40s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 25.0,
        ),
        closeTo(40.0, 0.001),
      );

      // 20% = 5x slower -> 50s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 20.0,
        ),
        closeTo(50.0, 0.001),
      );

      // 10% = 10x slower -> 100s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 10.0,
        ),
        closeTo(100.0, 0.001),
      );

      // 5% = 20x slower -> 200s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 5.0,
        ),
        closeTo(200.0, 0.001),
      );

      // 1% = 100x slower -> 1000s
      expect(
        SpeedMappingEngine.calculateConstantOutputDuration(
          sourceDurationSeconds: sourceDuration,
          speedPercent: 1.0,
        ),
        closeTo(1000.0, 0.001),
      );
    });

    test('Reverse calculation: Target Duration to Speed Percentage', () {
      const sourceDuration = 10.0;

      // Desired 40s output -> 25% speed
      expect(
        SpeedMappingEngine.calculateSpeedPercentFromTargetDuration(
          sourceDurationSeconds: sourceDuration,
          targetDurationSeconds: 40.0,
        ),
        closeTo(25.0, 0.001),
      );

      // Desired 20s output -> 50% speed
      expect(
        SpeedMappingEngine.calculateSpeedPercentFromTargetDuration(
          sourceDurationSeconds: sourceDuration,
          targetDurationSeconds: 20.0,
        ),
        closeTo(50.0, 0.001),
      );

      // Desired 13.333s output -> 75% speed
      expect(
        SpeedMappingEngine.calculateSpeedPercentFromTargetDuration(
          sourceDurationSeconds: sourceDuration,
          targetDurationSeconds: 13.33333,
        ),
        closeTo(75.0, 0.01),
      );
    });

    test('Slowdown and Playback multipliers', () {
      expect(SpeedMappingEngine.calculateSlowdownMultiplier(25.0), closeTo(4.0, 0.001));
      expect(SpeedMappingEngine.calculatePlaybackMultiplier(25.0), closeTo(0.25, 0.001));
      expect(SpeedMappingEngine.calculateSlowdownMultiplier(50.0), closeTo(2.0, 0.001));
      expect(SpeedMappingEngine.calculatePlaybackMultiplier(50.0), closeTo(0.5, 0.001));
    });

    test('Intermediate frame ratio matches prompt specification', () {
      // Prompt section 5:
      // "a 30 FPS source played at 25% speed with a 120 FPS output target requires approximately 16 output frames for each original frame interval"
      final framesPerInterval = SpeedMappingEngine.calculateFramesPerSourceInterval(
        sourceFps: 30.0,
        outputFps: 120.0,
        speedPercent: 25.0,
      );
      expect(framesPerInterval, closeTo(16.0, 0.001));

      // 60 FPS target at 50% speed from 30 FPS source -> (60/30) * 2 = 4 frames per interval
      final frames60to50 = SpeedMappingEngine.calculateFramesPerSourceInterval(
        sourceFps: 30.0,
        outputFps: 60.0,
        speedPercent: 50.0,
      );
      expect(frames60to50, closeTo(4.0, 0.001));
    });

    test('Total output frames calculation', () {
      // 10s source at 25% speed = 40s output at 60 FPS -> 2400 frames
      final totalFrames = SpeedMappingEngine.calculateTotalOutputFrames(
        sourceDurationSeconds: 10.0,
        speedPercent: 25.0,
        outputFps: 60,
      );
      expect(totalFrames, equals(2400));
    });
  });

  group('CubicBezierCurve & Speed Ramps', () {
    test('CubicBezier endpoints and monotonicity', () {
      const curve = CubicBezierCurve.easeInOut;
      expect(curve.transform(0.0), closeTo(0.0, 1e-4));
      expect(curve.transform(1.0), closeTo(1.0, 1e-4));
      expect(curve.transform(0.5), closeTo(0.5, 0.05));
    });

    test('Variable speed ramp output duration integration', () {
      // Ramp from 100% to 25% to 100% on a 10s clip
      final keyframes = [
        const SpeedKeyframe(id: '1', normalizedTime: 0.0, speedPercent: 100.0),
        const SpeedKeyframe(id: '2', normalizedTime: 0.3, speedPercent: 25.0),
        const SpeedKeyframe(id: '3', normalizedTime: 0.7, speedPercent: 25.0),
        const SpeedKeyframe(id: '4', normalizedTime: 1.0, speedPercent: 100.0),
      ];

      final duration = SpeedMappingEngine.calculateVariableOutputDuration(
        sourceDurationSeconds: 10.0,
        keyframes: keyframes,
      );

      // Duration must be longer than 10s (source) and less than 40s (constant 25%)
      expect(duration, greaterThan(15.0));
      expect(duration, lessThan(35.0));
    });

    test('Frame sample planning accurately brackets source frames and computes alpha', () {
      // 30 FPS source, 25% speed, 60 FPS output
      // Source frame duration = 1/30 = 0.03333s
      // Output frame duration = 1/60 = 0.01666s
      // Output frame 0 -> source time 0.0s -> frame 0, alpha = 0.0
      final f0 = SpeedMappingEngine.planFrameSample(
        outputFrameIndex: 0,
        outputFps: 60,
        sourceFps: 30.0,
        totalSourceFrames: 300,
        sourceDurationSeconds: 10.0,
        speedPercent: 25.0,
      );
      expect(f0.sourceFrameAIndex, equals(0));
      expect(f0.opticalFlowAlpha, closeTo(0.0, 0.001));
      expect(f0.isExactSourceFrame, isTrue);

      // Output frame 2 -> output time 2/60 = 0.03333s
      // Speed is 25% (0.25x), so source time = 0.03333 * 0.25 = 0.008333s
      // Source frame index = 0.008333 * 30 = 0.25
      // frameA = 0, frameB = 1, alpha = 0.25!
      final f2 = SpeedMappingEngine.planFrameSample(
        outputFrameIndex: 2,
        outputFps: 60,
        sourceFps: 30.0,
        totalSourceFrames: 300,
        sourceDurationSeconds: 10.0,
        speedPercent: 25.0,
      );
      expect(f2.sourceFrameAIndex, equals(0));
      expect(f2.sourceFrameBIndex, equals(1));
      expect(f2.opticalFlowAlpha, closeTo(0.25, 0.01));
      expect(f2.isExactSourceFrame, isFalse);
    });
  });
}
