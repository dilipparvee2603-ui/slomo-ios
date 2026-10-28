import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/speed_mapping_engine.dart';

class SpeedPresetChips extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  static const List<double> presets = [100.0, 75.0, 50.0, 40.0, 25.0, 20.0, 10.0, 5.0];

  const SpeedPresetChips({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: presets.map((preset) {
          final isSelected = (currentSpeed - preset).abs() < 0.1;
          final multiplier = SpeedMappingEngine.calculateSlowdownMultiplier(preset);
          final multString = preset == 100.0 ? '1×' : '${multiplier.toStringAsFixed(multiplier % 1 == 0 ? 0 : 1)}×';

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSpeedSelected(preset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentAmber.withOpacity(0.2) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.accentAmber : AppColors.divider,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.accentAmber.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${preset.toStringAsFixed(preset % 1 == 0 ? 0 : 1)}%',
                      style: TextStyle(
                        color: isSelected ? AppColors.accentAmber : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      multString,
                      style: TextStyle(
                        color: isSelected ? AppColors.accentAmber.withOpacity(0.9) : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
