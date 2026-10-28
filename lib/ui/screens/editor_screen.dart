import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_metadata.dart';
import '../../core/models/speed_keyframe.dart';
import '../../core/models/export_config.dart';
import '../../core/math/speed_mapping_engine.dart';
import '../../services/platform_bridge_service.dart';
import '../widgets/duration_calculator_card.dart';
import '../widgets/speed_preset_chips.dart';
import '../widgets/video_metadata_card.dart';
import '../widgets/timeline_ruler.dart';
import 'speed_curve_editor.dart';
import 'export_sheet.dart';
import 'render_progress_dialog.dart';

class EditorScreen extends StatefulWidget {
  final VideoMetadata metadata;

  const EditorScreen({super.key, required this.metadata});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  final PlatformBridgeService _platformBridge = PlatformBridgeService();

  double _currentSpeedPercent = 25.0; // Default to 25% (4x slow motion)
  bool _isVariableSpeedMode = false;
  late List<SpeedKeyframe> _keyframes;
  bool _isPlaying = false;
  double _currentPositionSeconds = 0.0;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _keyframes = [
      const SpeedKeyframe(id: 'start', normalizedTime: 0.0, speedPercent: 100.0),
      const SpeedKeyframe(id: 'mid1', normalizedTime: 0.25, speedPercent: 25.0),
      const SpeedKeyframe(id: 'mid2', normalizedTime: 0.75, speedPercent: 25.0),
      const SpeedKeyframe(id: 'end', normalizedTime: 1.0, speedPercent: 100.0),
    ];
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.metadata.path));
      await _videoController.initialize();
      _videoController.setLooping(true);

      _applyPlaybackSpeed();

      _videoController.addListener(() {
        if (mounted && _videoController.value.isInitialized) {
          setState(() {
            _currentPositionSeconds = _videoController.value.position.inMilliseconds / 1000.0;
            _isPlaying = _videoController.value.isPlaying;
          });
        }
      });

      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      print('Video player initialization warning: $e');
    }
  }

  void _applyPlaybackSpeed() {
    if (!_isVideoInitialized) return;
    final rate = SpeedMappingEngine.calculatePlaybackMultiplier(_currentSpeedPercent);
    // video_player supports playback rates from 0.25x to 2.0x
    final safeRate = rate.clamp(0.25, 2.0);
    _videoController.setPlaybackSpeed(safeRate);
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  void _onSpeedChanged(double newSpeed) {
    setState(() {
      _currentSpeedPercent = newSpeed;
    });
    _applyPlaybackSpeed();
  }

  void _togglePlayPause() {
    if (!_isVideoInitialized) return;
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
  }

  void _onSeek(double seconds) {
    if (!_isVideoInitialized) return;
    final ms = (seconds * 1000).round();
    _videoController.seekTo(Duration(milliseconds: ms));
  }

  void _openExportSheet() {
    final outputDur = _isVariableSpeedMode
        ? SpeedMappingEngine.calculateVariableOutputDuration(
            sourceDurationSeconds: widget.metadata.durationSeconds,
            keyframes: _keyframes,
          )
        : SpeedMappingEngine.calculateConstantOutputDuration(
            sourceDurationSeconds: widget.metadata.durationSeconds,
            speedPercent: _currentSpeedPercent,
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportSheet(
        metadata: widget.metadata,
        calculatedOutputDurationSeconds: outputDur,
        onStartExport: (config) => _startRender(config),
      ),
    );
  }

  void _startRender(ExportConfig config) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RenderProgressDialog(
        progressStream: _platformBridge.progressStream,
        platformBridge: _platformBridge,
        onCancel: () async {
          await _platformBridge.cancelRender();
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );

    // Trigger native render
    _platformBridge.startRender(
      sourceVideoPath: widget.metadata.path,
      speedPercent: _currentSpeedPercent,
      exportConfig: config,
      metadata: widget.metadata,
      keyframes: _isVariableSpeedMode ? _keyframes : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Slo-Mo Studio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _openExportSheet,
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Player Stage
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 240,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isVideoInitialized)
                        AspectRatio(
                          aspectRatio: _videoController.value.aspectRatio,
                          child: VideoPlayer(_videoController),
                        )
                      else
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.accentCyan),
                            SizedBox(height: 12),
                            Text('Loading Video...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),

                      // Speed badge watermark
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentAmber.withOpacity(0.5)),
                          ),
                          child: Text(
                            _isVariableSpeedMode
                                ? 'RAMP: ${SpeedMappingEngine.evaluateSpeedAtSourceNormalized(
                                    normalizedSourceTime: widget.metadata.durationSeconds > 0
                                        ? (_currentPositionSeconds / widget.metadata.durationSeconds)
                                        : 0.0,
                                    keyframes: _keyframes,
                                  ).toStringAsFixed(1)}%'
                                : '${_currentSpeedPercent.toStringAsFixed(_currentSpeedPercent % 1 == 0 ? 0 : 1)}% SPEED',
                            style: const TextStyle(
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Play/Pause Overlay Button
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Timeline & Playhead
              TimelineRuler(
                durationSeconds: widget.metadata.durationSeconds,
                currentPositionSeconds: _currentPositionSeconds,
                keyframes: _isVariableSpeedMode ? _keyframes : const [],
                onSeek: _onSeek,
              ),

              const SizedBox(height: 16),

              // Mode Switcher: Constant Speed vs Variable Ramp
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isVariableSpeedMode = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isVariableSpeedMode ? AppColors.surfaceElevated : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: !_isVariableSpeedMode ? Border.all(color: AppColors.accentAmber) : null,
                          ),
                          child: Center(
                            child: Text(
                              'Constant Speed',
                              style: TextStyle(
                                color: !_isVariableSpeedMode ? AppColors.accentAmber : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isVariableSpeedMode = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isVariableSpeedMode ? AppColors.surfaceElevated : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: _isVariableSpeedMode ? Border.all(color: AppColors.accentCyan) : null,
                          ),
                          child: Center(
                            child: Text(
                              'Speed Ramp (Variable)',
                              style: TextStyle(
                                color: _isVariableSpeedMode ? AppColors.accentCyan : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mode 1: Constant Speed Controls
              if (!_isVariableSpeedMode) ...[
                SpeedPresetChips(
                  currentSpeed: _currentSpeedPercent,
                  onSpeedSelected: _onSpeedChanged,
                ),
                const SizedBox(height: 16),
                DurationCalculatorCard(
                  sourceDurationSeconds: widget.metadata.durationSeconds,
                  currentSpeedPercent: _currentSpeedPercent,
                  sourceFps: widget.metadata.fps,
                  onSpeedChanged: _onSpeedChanged,
                ),
              ] else ...[
                // Mode 2: Variable Speed Ramp Curve Editor
                SpeedCurveEditor(
                  sourceDurationSeconds: widget.metadata.durationSeconds,
                  keyframes: _keyframes,
                  onKeyframesChanged: (updated) => setState(() => _keyframes = updated),
                  currentPositionSeconds: _currentPositionSeconds,
                  onSeek: _onSeek,
                ),
              ],

              const SizedBox(height: 16),

              // Source Video Metadata Card
              VideoMetadataCard(metadata: widget.metadata),
            ],
          ),
        ),
      ),
    );
  }
}
