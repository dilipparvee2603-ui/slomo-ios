import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/speed_mapping_engine.dart';

class DurationCalculatorCard extends StatefulWidget {
  final double sourceDurationSeconds;
  final double currentSpeedPercent;
  final double sourceFps;
  final int targetFps;
  final ValueChanged<double> onSpeedChanged;

  const DurationCalculatorCard({
    super.key,
    required this.sourceDurationSeconds,
    required this.currentSpeedPercent,
    required this.sourceFps,
    this.targetFps = 60,
    required this.onSpeedChanged,
  });

  @override
  State<DurationCalculatorCard> createState() => _DurationCalculatorCardState();
}

class _DurationCalculatorCardState extends State<DurationCalculatorCard> {
  late TextEditingController _speedController;
  late TextEditingController _durationController;
  bool _isEditingDuration = false;

  @override
  void initState() {
    super.initState();
    _speedController = TextEditingController(
      text: widget.currentSpeedPercent.toStringAsFixed(widget.currentSpeedPercent % 1 == 0 ? 0 : 2),
    );
    final outputDur = SpeedMappingEngine.calculateConstantOutputDuration(
      sourceDurationSeconds: widget.sourceDurationSeconds,
      speedPercent: widget.currentSpeedPercent,
    );
    _durationController = TextEditingController(text: outputDur.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant DurationCalculatorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSpeedPercent != widget.currentSpeedPercent && !_isEditingDuration) {
      _speedController.text = widget.currentSpeedPercent.toStringAsFixed(
        widget.currentSpeedPercent % 1 == 0 ? 0 : 2,
      );
      final outputDur = SpeedMappingEngine.calculateConstantOutputDuration(
        sourceDurationSeconds: widget.sourceDurationSeconds,
        speedPercent: widget.currentSpeedPercent,
      );
      _durationController.text = outputDur.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _speedController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _onSpeedTextSubmitted(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      final clamped = parsed.clamp(1.0, 100.0);
      widget.onSpeedChanged(clamped);
      final outputDur = SpeedMappingEngine.calculateConstantOutputDuration(
        sourceDurationSeconds: widget.sourceDurationSeconds,
        speedPercent: clamped,
      );
      _durationController.text = outputDur.toStringAsFixed(2);
    }
  }

  void _onDurationTextSubmitted(String value) {
    final targetDuration = double.tryParse(value);
    if (targetDuration != null && targetDuration > 0) {
      final calculatedSpeed = SpeedMappingEngine.calculateSpeedPercentFromTargetDuration(
        sourceDurationSeconds: widget.sourceDurationSeconds,
        targetDurationSeconds: targetDuration,
      );
      _isEditingDuration = false;
      widget.onSpeedChanged(calculatedSpeed);
      _speedController.text = calculatedSpeed.toStringAsFixed(
        calculatedSpeed % 1 == 0 ? 0 : 2,
      );
    }
  }

  String _formatTimecode(double seconds) {
    final totalSec = seconds.floor();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    final ms = ((seconds - totalSec) * 100).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final outputDuration = SpeedMappingEngine.calculateConstantOutputDuration(
      sourceDurationSeconds: widget.sourceDurationSeconds,
      speedPercent: widget.currentSpeedPercent,
    );
    final slowdown = SpeedMappingEngine.calculateSlowdownMultiplier(widget.currentSpeedPercent);
    final framesPerInterval = SpeedMappingEngine.calculateFramesPerSourceInterval(
      sourceFps: widget.sourceFps,
      outputFps: widget.targetFps.toDouble(),
      speedPercent: widget.currentSpeedPercent,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.speed, color: AppColors.accentAmber, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Speed / Duration',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  '${slowdown.toStringAsFixed(2)}× Slower',
                  style: const TextStyle(
                    color: AppColors.accentAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two input fields: Speed % and Target Duration (s)
          Row(
            children: [
              // Speed % input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speed %',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _speedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: AppColors.accentAmber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        suffixText: '%',
                        suffixStyle: const TextStyle(color: AppColors.accentAmber),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.accentAmber),
                        ),
                      ),
                      onSubmitted: _onSpeedTextSubmitted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Target Duration input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Duration (s)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _durationController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        suffixText: 's',
                        suffixStyle: const TextStyle(color: AppColors.accentCyan),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.accentCyan),
                        ),
                      ),
                      onTap: () => _isEditingDuration = true,
                      onSubmitted: _onDurationTextSubmitted,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Speed Slider (1% to 100%)
          Row(
            children: [
              const Text('1%', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accentAmber,
                    inactiveTrackColor: AppColors.surfaceElevated,
                    thumbColor: AppColors.accentAmber,
                    overlayColor: AppColors.accentAmber.withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: widget.currentSpeedPercent.clamp(1.0, 100.0),
                    min: 1.0,
                    max: 100.0,
                    onChanged: (val) {
                      _isEditingDuration = false;
                      widget.onSpeedChanged(val);
                      _speedController.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
                      final outDur = SpeedMappingEngine.calculateConstantOutputDuration(
                        sourceDurationSeconds: widget.sourceDurationSeconds,
                        speedPercent: val,
                      );
                      _durationController.text = outDur.toStringAsFixed(2);
                    },
                  ),
                ),
              ),
              const Text('100%', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 12),

          // Duration & Frame info row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Source', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimecode(widget.sourceDurationSeconds),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Output', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimecode(outputDuration),
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: AppColors.divider),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Intermediate Ratio', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${framesPerInterval.toStringAsFixed(1)} frames/interval',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
