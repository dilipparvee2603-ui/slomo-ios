/// 2D Cubic Bezier curve evaluator with Newton-Raphson parameter inversion
/// for smooth timing and Premiere Pro-style speed ramping.
class CubicBezierCurve {
  final double p1x;
  final double p1y;
  final double p2x;
  final double p2y;

  /// Control points from (0, 0) to (1, 1) with handle 1 at (p1x, p1y) and handle 2 at (p2x, p2y)
  const CubicBezierCurve(this.p1x, this.p1y, this.p2x, this.p2y);

  // Standard Premiere / CSS Ease presets
  static const ease = CubicBezierCurve(0.25, 0.1, 0.25, 1.0);
  static const easeIn = CubicBezierCurve(0.42, 0.0, 1.0, 1.0);
  static const easeOut = CubicBezierCurve(0.0, 0.0, 0.58, 1.0);
  static const easeInOut = CubicBezierCurve(0.42, 0.0, 0.58, 1.0);
  static const linear = CubicBezierCurve(0.0, 0.0, 1.0, 1.0);

  /// Evaluate x coordinate given curve parameter t in [0, 1]
  double sampleCurveX(double t) {
    // ((1 - 3*p2x + 3*p1x)*t + (3*p2x - 6*p1x))*t + 3*p1x)*t
    final cx = 3.0 * p1x;
    final bx = 3.0 * (p2x - p1x) - cx;
    final ax = 1.0 - cx - bx;
    return ((ax * t + bx) * t + cx) * t;
  }

  /// Evaluate y coordinate given curve parameter t in [0, 1]
  double sampleCurveY(double t) {
    final cy = 3.0 * p1y;
    final by = 3.0 * (p2y - p1y) - cy;
    final ay = 1.0 - cy - by;
    return ((ay * t + by) * t + cy) * t;
  }

  /// Derivative of x with respect to t
  double sampleCurveDerivativeX(double t) {
    final cx = 3.0 * p1x;
    final bx = 3.0 * (p2x - p1x) - cx;
    final ax = 1.0 - cx - bx;
    return (3.0 * ax * t + 2.0 * bx) * t + cx;
  }

  /// Solves for t given x in [0, 1] using Newton-Raphson iteration with bisection fallback
  double solveCurveX(double x, {double epsilon = 1e-6}) {
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;

    // First try a few Newton-Raphson iterations
    double t2 = x;
    for (int i = 0; i < 8; i++) {
      final x2 = sampleCurveX(t2) - x;
      if (x2.abs() < epsilon) return t2;
      final d2 = sampleCurveDerivativeX(t2);
      if (d2.abs() < 1e-6) break;
      t2 = t2 - x2 / d2;
    }

    // Fallback to binary bisection search
    double t0 = 0.0;
    double t1 = 1.0;
    t2 = x;

    while (t0 < t1) {
      final x2 = sampleCurveX(t2);
      if ((x2 - x).abs() < epsilon) return t2;
      if (x > x2) {
        t0 = t2;
      } else {
        t1 = t2;
      }
      t2 = (t1 + t0) * 0.5;
    }

    return t2;
  }

  /// Given normalized input progress x in [0, 1], returns output progress y in [0, 1]
  double transform(double x) {
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;
    final t = solveCurveX(x);
    return sampleCurveY(t).clamp(0.0, 1.0);
  }
}
