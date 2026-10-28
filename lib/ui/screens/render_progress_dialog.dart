import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/render_progress.dart';
import '../../services/platform_bridge_service.dart';

class RenderProgressDialog extends StatefulWidget {
  final Stream<RenderProgress> progressStream;
  final VoidCallback onCancel;
  final PlatformBridgeService platformBridge;

  const RenderProgressDialog({
    super.key,
    required this.progressStream,
    required this.onCancel,
    required this.platformBridge,
  });

  @override
  State<RenderProgressDialog> createState() => _RenderProgressDialogState();
}

class _RenderProgressDialogState extends State<RenderProgressDialog> {
  RenderProgress _progress = const RenderProgress(
    status: RenderStatus.preparing,
    statusMessage: 'Initializing optical flow engine...',
  );
  bool _isSavingToPhotos = false;
  bool _savedToPhotosSuccess = false;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _progress = event;
        });
      }
    });
  }

  Future<void> _saveToPhotos() async {
    if (_progress.outputPath == null) return;
    setState(() => _isSavingToPhotos = true);
    final success = await widget.platformBridge.saveToPhotos(_progress.outputPath!);
    if (mounted) {
      setState(() {
        _isSavingToPhotos = false;
        _savedToPhotosSuccess = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Saved to Photos library successfully!' : 'Failed to save to Photos.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _shareVideo() async {
    if (_progress.outputPath == null) return;
    await widget.platformBridge.shareVideo(_progress.outputPath!);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _progress.status == RenderStatus.completed;
    final isError = _progress.status == RenderStatus.error;

    return WillPopScope(
      onWillPop: () async => isDone || isError,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon header
              if (isDone)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                )
              else if (isError)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.blur_on, color: AppColors.accentCyan, size: 48),
                ),

              const SizedBox(height: 16),

              Text(
                isDone
                    ? 'Render Completed!'
                    : isError
                        ? 'Render Failed'
                        : 'Generating Optical Flow Slo-Mo',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                isError
                    ? (_progress.errorMessage ?? 'An unknown error occurred during render.')
                    : _progress.statusMessage.isNotEmpty
                        ? _progress.statusMessage
                        : 'Synthesizing motion-compensated frames...',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Progress bar
              if (!isDone && !isError) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress.progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_progress.progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Frame ${_progress.currentFrame} / ${_progress.totalFrames}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          const Text('Speed', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '${_progress.fpsProcessing.toStringAsFixed(1)} FPS',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Elapsed', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '${_progress.elapsedSeconds.toStringAsFixed(0)}s',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ETA', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            _progress.formattedEta,
                            style: const TextStyle(color: AppColors.accentAmber, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel Render'),
                  ),
                ),
              ],

              // Actions when done
              if (isDone) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingToPhotos ? null : _saveToPhotos,
                        icon: _isSavingToPhotos
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_savedToPhotosSuccess ? Icons.check : Icons.photo_library, size: 16),
                        label: Text(_savedToPhotosSuccess ? 'Saved' : 'Save Photos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _savedToPhotosSuccess ? AppColors.success : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareVideo,
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('Share Video'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.divider),
                          backgroundColor: AppColors.surfaceElevated,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ],

              // Actions on error
              if (isError) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
