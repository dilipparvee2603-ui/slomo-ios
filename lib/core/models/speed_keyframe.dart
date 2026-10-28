enum KeyframeInterpolation {
  linear,
  smoothBezier,
  hold, // Freeze frame
}

/// A keyframe representing playback speed at a normalized source position (0.0 to 1.0)
/// or an absolute source timestamp.
class SpeedKeyframe {
  final String id;
  /// Normalized position in source clip: 0.0 (start) to 1.0 (end)
  final double normalizedTime;
  /// Speed percentage (1.0% to 100.0%, where 100.0% is normal speed, 25.0% is 4x slower)
  final double speedPercent;
  /// Curve interpolation type to the next keyframe
  final KeyframeInterpolation interpolation;
  /// Bezier control handle parameters (normalized control point offset: -1.0 to +1.0)
  final double handleInX;
  final double handleInY;
  final double handleOutX;
  final double handleOutY;

  const SpeedKeyframe({
    required this.id,
    required this.normalizedTime,
    required this.speedPercent,
    this.interpolation = KeyframeInterpolation.smoothBezier,
    this.handleInX = -0.25,
    this.handleInY = 0.0,
    this.handleOutX = 0.25,
    this.handleOutY = 0.0,
  });

  /// Multiplier relative to normal playback (e.g. 25% speed = 0.25x speed multiplier, 4x duration)
  double get speedMultiplier => (speedPercent / 100.0).clamp(0.01, 10.0);

  SpeedKeyframe copyWith({
    String? id,
    double? normalizedTime,
    double? speedPercent,
    KeyframeInterpolation? interpolation,
    double? handleInX,
    double? handleInY,
    double? handleOutX,
    double? handleOutY,
  }) {
    return SpeedKeyframe(
      id: id ?? this.id,
      normalizedTime: normalizedTime ?? this.normalizedTime,
      speedPercent: speedPercent ?? this.speedPercent,
      interpolation: interpolation ?? this.interpolation,
      handleInX: handleInX ?? this.handleInX,
      handleInY: handleInY ?? this.handleInY,
      handleOutX: handleOutX ?? this.handleOutX,
      handleOutY: handleOutY ?? this.handleOutY,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'normalizedTime': normalizedTime,
    'speedPercent': speedPercent,
    'interpolation': interpolation.index,
    'handleInX': handleInX,
    'handleInY': handleInY,
    'handleOutX': handleOutX,
    'handleOutY': handleOutY,
  };

  factory SpeedKeyframe.fromMap(Map<String, dynamic> map) {
    return SpeedKeyframe(
      id: map['id'] as String? ?? '',
      normalizedTime: (map['normalizedTime'] as num?)?.toDouble() ?? 0.0,
      speedPercent: (map['speedPercent'] as num?)?.toDouble() ?? 100.0,
      interpolation: KeyframeInterpolation.values[(map['interpolation'] as num?)?.toInt() ?? 1],
      handleInX: (map['handleInX'] as num?)?.toDouble() ?? -0.25,
      handleInY: (map['handleInY'] as num?)?.toDouble() ?? 0.0,
      handleOutX: (map['handleOutX'] as num?)?.toDouble() ?? 0.25,
      handleOutY: (map['handleOutY'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
