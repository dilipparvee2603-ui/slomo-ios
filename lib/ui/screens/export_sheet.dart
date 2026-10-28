import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/export_config.dart';
import '../../core/models/video_metadata.dart';

class ExportSheet extends StatefulWidget {
  final VideoMetadata metadata;
  final double calculatedOutputDurationSeconds;
  final ValueChanged<ExportConfig> onStartExport;

  const ExportSheet({
    super.key,
    required this.metadata,
    required this.calculatedOutputDurationSeconds,
    required this.onStartExport,
  });

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  VideoContainer _container = VideoContainer.mp4;
  VideoCodec _codec = VideoCodec.hevc;
  OutputResolution _resolution = OutputResolution.source;
  OutputFrameRate _frameRate = OutputFrameRate.fps60;
  OpticalFlowEngineType _engineType = OpticalFlowEngineType.appleVisionMetal;
  AudioMode _audioMode = AudioMode.retimedPitchPreserved;
  final BitrateQuality _quality = BitrateQuality.high;

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentConfig = ExportConfig(
      container: _container,
      codec: _codec,
      resolution: _resolution,
      frameRate: _frameRate,
      engineType: _engineType,
      audioMode: _audioMode,
      quality: _quality,
    );

    final estimatedBytes = currentConfig.estimateOutputSizeBytes(
      outputDurationSeconds: widget.calculatedOutputDurationSeconds,
      baseWidth: widget.metadata.displayWidth,
      baseHeight: widget.metadata.displayHeight,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Export Configuration',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target Frame Rate
            const Text('Output Frame Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: OutputFrameRate.values.map((fps) {
                final isSel = _frameRate == fps;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          '${fps.fps} FPS',
                          style: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceElevated,
                      onSelected: (val) {
                        if (val) setState(() => _frameRate = fps);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Resolution
            const Text('Resolution', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Source (${widget.metadata.displayWidth}p)')),
                    selected: _resolution == OutputResolution.source,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceElevated,
                    onSelected: (val) => setState(() => _resolution = OutputResolution.source),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('1080p FHD')),
                    selected: _resolution == OutputResolution.fhd1080p,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceElevated,
                    onSelected: (val) => setState(() => _resolution = OutputResolution.fhd1080p),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('4K UHD')),
                    selected: _resolution == OutputResolution.uhd4k,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceElevated,
                    onSelected: (val) => setState(() => _resolution = OutputResolution.uhd4k),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Codec & Container
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Codec', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<VideoCodec>(
                        value: _codec,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                        ),
                        items: const [
                          DropdownMenuItem(value: VideoCodec.hevc, child: Text('HEVC (H.265)', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: VideoCodec.h264, child: Text('H.264 (AVC)', style: TextStyle(color: AppColors.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _codec = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Container', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<VideoContainer>(
                        value: _container,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                        ),
                        items: const [
                          DropdownMenuItem(value: VideoContainer.mp4, child: Text('MP4', style: TextStyle(color: AppColors.textPrimary))),
                          DropdownMenuItem(value: VideoContainer.mov, child: Text('QuickTime (.MOV)', style: TextStyle(color: AppColors.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _container = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optical Flow Engine
            const Text('Interpolation Engine', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  RadioListTile<OpticalFlowEngineType>(
                    title: const Text('Vision + Metal Optical Flow (Recommended)', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Apple Vision motion vectors with Metal GPU bidirectional warping & blend', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    value: OpticalFlowEngineType.appleVisionMetal,
                    groupValue: _engineType,
                    activeColor: AppColors.accentCyan,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _engineType = val);
                    },
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  RadioListTile<OpticalFlowEngineType>(
                    title: const Text('VideoToolbox VTFrameProcessor', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Hardware frame-rate converter (iOS 16+ where supported by hardware)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    value: OpticalFlowEngineType.appleVTFrameProcessor,
                    groupValue: _engineType,
                    activeColor: AppColors.accentCyan,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _engineType = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Audio Mode
            const Text('Audio Handling', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<AudioMode>(
              value: _audioMode,
              dropdownColor: AppColors.surfaceElevated,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
              ),
              items: const [
                DropdownMenuItem(value: AudioMode.retimedPitchPreserved, child: Text('Retimed (Pitch-Preserved)', style: TextStyle(color: AppColors.textPrimary))),
                DropdownMenuItem(value: AudioMode.mute, child: Text('Mute (Recommended for < 20% Slo-Mo)', style: TextStyle(color: AppColors.textPrimary))),
                DropdownMenuItem(value: AudioMode.originalSpeed, child: Text('Original Speed Audio', style: TextStyle(color: AppColors.textPrimary))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _audioMode = val);
              },
            ),
            const SizedBox(height: 20),

            // Summary Card (Estimated size, duration)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rendered Duration', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.calculatedOutputDurationSeconds.toStringAsFixed(2)}s',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Est. Output Size', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(estimatedBytes),
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start Render button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStartExport(currentConfig);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.slow_motion_video, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Render Slow-Motion Video',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
