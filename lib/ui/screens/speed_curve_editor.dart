import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/speed_keyframe.dart';
import '../../core/math/speed_mapping_engine.dart';

class SpeedCurveEditor extends StatefulWidget {
  final double sourceDurationSeconds;
  final List<SpeedKeyframe> keyframes;
  final ValueChanged<List<SpeedKeyframe>> onKeyframesChanged;
  final double currentPositionSeconds;
  final ValueChanged<double> onSeek;

  const SpeedCurveEditor({
    super.key,
    required this.sourceDurationSeconds,
    required this.keyframes,
    required this.onKeyframesChanged,
    required this.currentPositionSeconds,
    required this.onSeek,
  });

  @override
  State<SpeedCurveEditor> createState() => _SpeedCurveEditorState();
}

class _SpeedCurveEditorState extends State<SpeedCurveEditor> {
  int? _selectedKeyframeIndex;

  @override
  void initState() {
    super.initState();
    if (widget.keyframes.isNotEmpty) {
      _selectedKeyframeIndex = 0;
    }
  }

  void _addKeyframeAtCurrentPosition() {
    final normTime = widget.sourceDurationSeconds > 0
        ? (widget.currentPositionSeconds / widget.sourceDurationSeconds).clamp(0.0, 1.0)
        : 0.0;

    final currentSpeed = SpeedMappingEngine.evaluateSpeedAtSourceNormalized(
      normalizedSourceTime: normTime,
      keyframes: widget.keyframes,
    );

    final newKeyframe = SpeedKeyframe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      normalizedTime: normTime,
      speedPercent: currentSpeed,
      interpolation: KeyframeInterpolation.smoothBezier,
    );

    final updated = List<SpeedKeyframe>.from(widget.keyframes)..add(newKeyframe);
    updated.sort((a, b) => a.normalizedTime.compareTo(b.normalizedTime));
    widget.onKeyframesChanged(updated);

    setState(() {
      _selectedKeyframeIndex = updated.indexOf(newKeyframe);
    });
  }

  void _applyStandardRampPreset() {
    // Standard ramp: 100% -> 25% -> 25% -> 100%
    final preset = [
      const SpeedKeyframe(id: 'k1', normalizedTime: 0.0, speedPercent: 100.0),
      const SpeedKeyframe(id: 'k2', normalizedTime: 0.25, speedPercent: 25.0),
      const SpeedKeyframe(id: 'k3', normalizedTime: 0.75, speedPercent: 25.0),
      const SpeedKeyframe(id: 'k4', normalizedTime: 1.0, speedPercent: 100.0),
    ];
    widget.onKeyframesChanged(preset);
    setState(() {
      _selectedKeyframeIndex = 1;
    });
  }

  void _applyFreezeFramePreset() {
    // Freeze frame in middle: 100% -> 1% (freeze) -> 100%
    final normTime = widget.sourceDurationSeconds > 0
        ? (widget.currentPositionSeconds / widget.sourceDurationSeconds).clamp(0.05, 0.85)
        : 0.4;
    final preset = [
      const SpeedKeyframe(id: 'k1', normalizedTime: 0.0, speedPercent: 100.0),
      SpeedKeyframe(id: 'k2', normalizedTime: normTime, speedPercent: 1.0, interpolation: KeyframeInterpolation.hold),
      SpeedKeyframe(id: 'k3', normalizedTime: normTime + 0.1, speedPercent: 1.0, interpolation: KeyframeInterpolation.hold),
      const SpeedKeyframe(id: 'k4', normalizedTime: 1.0, speedPercent: 100.0),
    ];
    widget.onKeyframesChanged(preset);
    setState(() {
      _selectedKeyframeIndex = 1;
    });
  }

  void _resetSpeedCurve() {
    final def = [
      const SpeedKeyframe(id: 'k1', normalizedTime: 0.0, speedPercent: 100.0),
      const SpeedKeyframe(id: 'k2', normalizedTime: 1.0, speedPercent: 100.0),
    ];
    widget.onKeyframesChanged(def);
    setState(() {
      _selectedKeyframeIndex = 0;
    });
  }

  void _deleteSelectedKeyframe() {
    if (_selectedKeyframeIndex == null) return;
    if (widget.keyframes.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 keyframes (start & end) must be maintained.')),
      );
      return;
    }

    final updated = List<SpeedKeyframe>.from(widget.keyframes);
    updated.removeAt(_selectedKeyframeIndex!);
    widget.onKeyframesChanged(updated);
    setState(() {
      _selectedKeyframeIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedKf = (_selectedKeyframeIndex != null &&
            _selectedKeyframeIndex! < widget.keyframes.length)
        ? widget.keyframes[_selectedKeyframeIndex!]
        : null;

    final outputDuration = SpeedMappingEngine.calculateVariableOutputDuration(
      sourceDurationSeconds: widget.sourceDurationSeconds,
      keyframes: widget.keyframes,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Speed Ramp Curve',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _resetSpeedCurve,
                    icon: const Icon(Icons.restart_alt, size: 14, color: AppColors.textSecondary),
                    label: const Text('Reset', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Preset buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _applyStandardRampPreset,
                  icon: const Icon(Icons.auto_graph, size: 14, color: AppColors.accentAmber),
                  label: const Text('100%→25%→100%', style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _applyFreezeFramePreset,
                  icon: const Icon(Icons.pause_circle_outline, size: 14, color: AppColors.accentCyan),
                  label: const Text('Freeze Frame', style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Visual Speed Curve Canvas
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: AppColors.surfaceElevated,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        // Find closest keyframe to tap
                        final tapNormX = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        int closestIdx = 0;
                        double minDist = 9999.0;
                        for (int i = 0; i < widget.keyframes.length; i++) {
                          final dist = (widget.keyframes[i].normalizedTime - tapNormX).abs();
                          if (dist < minDist) {
                            minDist = dist;
                            closestIdx = i;
                          }
                        }
                        if (minDist < 0.1) {
                          setState(() {
                            _selectedKeyframeIndex = closestIdx;
                          });
                        }
                      },
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, 140),
                        painter: _CurveGraphPainter(
                          keyframes: widget.keyframes,
                          selectedIndex: _selectedKeyframeIndex,
                          currentPositionNorm: widget.sourceDurationSeconds > 0
                              ? (widget.currentPositionSeconds / widget.sourceDurationSeconds).clamp(0.0, 1.0)
                              : 0.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Keyframe editor controls row
          if (selectedKf != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Keyframe #${_selectedKeyframeIndex! + 1} at ${(selectedKf.normalizedTime * 100).toStringAsFixed(0)}% clip',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.keyframes.length > 2 &&
                          _selectedKeyframeIndex != 0 &&
                          _selectedKeyframeIndex != widget.keyframes.length - 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _deleteSelectedKeyframe,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Speed: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(
                        '${selectedKf.speedPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.accentAmber,
                            inactiveTrackColor: AppColors.surface,
                            thumbColor: AppColors.accentAmber,
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: selectedKf.speedPercent.clamp(1.0, 100.0),
                            min: 1.0,
                            max: 100.0,
                            onChanged: (newSpeed) {
                              final updated = List<SpeedKeyframe>.from(widget.keyframes);
                              updated[_selectedKeyframeIndex!] = selectedKf.copyWith(speedPercent: newSpeed);
                              widget.onKeyframesChanged(updated);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Interpolation selector
                  Row(
                    children: [
                      const Text('Curve: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Smooth Bezier', style: TextStyle(fontSize: 11)),
                        selected: selectedKf.interpolation == KeyframeInterpolation.smoothBezier,
                        onSelected: (val) {
                          if (val) {
                            final updated = List<SpeedKeyframe>.from(widget.keyframes);
                            updated[_selectedKeyframeIndex!] = selectedKf.copyWith(
                              interpolation: KeyframeInterpolation.smoothBezier,
                            );
                            widget.onKeyframesChanged(updated);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Linear', style: TextStyle(fontSize: 11)),
                        selected: selectedKf.interpolation == KeyframeInterpolation.linear,
                        onSelected: (val) {
                          if (val) {
                            final updated = List<SpeedKeyframe>.from(widget.keyframes);
                            updated[_selectedKeyframeIndex!] = selectedKf.copyWith(
                              interpolation: KeyframeInterpolation.linear,
                            );
                            widget.onKeyframesChanged(updated);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Hold', style: TextStyle(fontSize: 11)),
                        selected: selectedKf.interpolation == KeyframeInterpolation.hold,
                        onSelected: (val) {
                          if (val) {
                            final updated = List<SpeedKeyframe>.from(widget.keyframes);
                            updated[_selectedKeyframeIndex!] = selectedKf.copyWith(
                              interpolation: KeyframeInterpolation.hold,
                            );
                            widget.onKeyframesChanged(updated);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action row: Add Keyframe at Playhead & Total Output Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _addKeyframeAtCurrentPosition,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Keyframe at Playhead', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              Text(
                'Rendered Duration: ${outputDuration.toStringAsFixed(2)}s',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurveGraphPainter extends CustomPainter {
  final List<SpeedKeyframe> keyframes;
  final int? selectedIndex;
  final double currentPositionNorm;

  _CurveGraphPainter({
    required this.keyframes,
    required this.selectedIndex,
    required this.currentPositionNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.divider.withOpacity(0.5)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines (100%, 75%, 50%, 25%, 0%)
    for (int pct = 0; pct <= 100; pct += 25) {
      final y = size.height - (pct / 100.0) * (size.height - 20) - 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (keyframes.isEmpty) return;

    final curvePaint = Paint()
      ..color = AppColors.accentAmber
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.accentAmber.withOpacity(0.25), AppColors.accentAmber.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final samples = 100;
    for (int i = 0; i <= samples; i++) {
      final normX = i / samples.toDouble();
      final speed = SpeedMappingEngine.evaluateSpeedAtSourceNormalized(
        normalizedSourceTime: normX,
        keyframes: keyframes,
      ).clamp(1.0, 100.0);

      final px = normX * size.width;
      final py = size.height - (speed / 100.0) * (size.height - 24) - 12;

      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, size.height);
        fillPath.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        fillPath.lineTo(px, py);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, curvePaint);

    // Draw playhead vertical line
    final playheadX = currentPositionNorm * size.width;
    final playheadPaint = Paint()
      ..color = AppColors.accentCyan
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, size.height), playheadPaint);

    // Draw keyframe point diamonds
    for (int i = 0; i < keyframes.length; i++) {
      final kf = keyframes[i];
      final px = kf.normalizedTime * size.width;
      final py = size.height - (kf.speedPercent / 100.0) * (size.height - 24) - 12;
      final isSel = (selectedIndex == i);

      final pointPaint = Paint()
        ..color = isSel ? Colors.white : AppColors.accentAmber
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), isSel ? 6.0 : 4.0, pointPaint);
      if (isSel) {
        final ringPaint = Paint()
          ..color = AppColors.accentAmber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(px, py), 9.0, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurveGraphPainter oldDelegate) => true;
}
