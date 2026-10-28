import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/speed_keyframe.dart';

class TimelineRuler extends StatelessWidget {
  final double durationSeconds;
  final double currentPositionSeconds;
  final double trimStartSeconds;
  final double trimEndSeconds;
  final List<SpeedKeyframe> keyframes;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onTrimStartChanged;
  final ValueChanged<double>? onTrimEndChanged;

  const TimelineRuler({
    super.key,
    required this.durationSeconds,
    required this.currentPositionSeconds,
    this.trimStartSeconds = 0.0,
    this.trimEndSeconds = 0.0,
    this.keyframes = const [],
    required this.onSeek,
    this.onTrimStartChanged,
    this.onTrimEndChanged,
  });

  String _formatTimecode(double seconds) {
    final totalSec = seconds.floor();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    final ms = ((seconds - totalSec) * 100).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTrimEnd = trimEndSeconds > 0 ? trimEndSeconds : durationSeconds;
    final progress = durationSeconds > 0 ? (currentPositionSeconds / durationSeconds).clamp(0.0, 1.0) : 0.0;
    final trimStartNorm = durationSeconds > 0 ? (trimStartSeconds / durationSeconds).clamp(0.0, 1.0) : 0.0;
    final trimEndNorm = durationSeconds > 0 ? (effectiveTrimEnd / durationSeconds).clamp(0.0, 1.0) : 1.0;

    return Column(
      children: [
        // Timecode display row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimecode(currentPositionSeconds),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTimecode(durationSeconds),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Interactive Timeline Track
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && durationSeconds > 0) {
              final localPos = details.localPosition.dx.clamp(0.0, box.size.width);
              final ratio = localPos / box.size.width;
              onSeek(ratio * durationSeconds);
            }
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && durationSeconds > 0) {
              final localPos = details.localPosition.dx.clamp(0.0, box.size.width);
              final ratio = localPos / box.size.width;
              onSeek(ratio * durationSeconds);
            }
          },
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final playheadX = width * progress;
                final startX = width * trimStartNorm;
                final endX = width * trimEndNorm;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Active trim region highlight
                    Positioned(
                      left: startX,
                      width: (endX - startX).clamp(0.0, width),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          border: Border.symmetric(
                            vertical: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // Ruler tick marks
                    CustomPaint(
                      size: Size(width, 38),
                      painter: _RulerPainter(),
                    ),

                    // Keyframe indicators
                    ...keyframes.map((kf) {
                      final kfX = width * kf.normalizedTime;
                      return Positioned(
                        left: kfX - 4,
                        top: 14,
                        child: Transform.rotate(
                          angle: 0.785398, // 45 deg diamond
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Playhead needle
                    Positioned(
                      left: (playheadX - 1).clamp(0.0, width - 2),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2.5,
                        color: AppColors.accentCyan,
                      ),
                    ),

                    // Playhead thumb head
                    Positioned(
                      left: (playheadX - 5).clamp(0.0, width - 10),
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.accentCyan,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintMajor = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1.0;

    final paintMinor = Paint()
      ..color = AppColors.textMuted.withOpacity(0.4)
      ..strokeWidth = 1.0;

    final count = 20;
    final step = size.width / count;

    for (int i = 0; i <= count; i++) {
      final x = i * step;
      final isMajor = i % 5 == 0;
      final height = isMajor ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        isMajor ? paintMajor : paintMinor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
