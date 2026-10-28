import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_metadata.dart';

class VideoMetadataCard extends StatelessWidget {
  final VideoMetadata metadata;

  const VideoMetadataCard({super.key, required this.metadata});

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required String value,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                value,
                style: TextStyle(
                  color: accentColor ?? AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resLabel = '${metadata.displayWidth}×${metadata.displayHeight}';
    final is4K = metadata.displayWidth >= 3840 || metadata.displayHeight >= 3840;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  metadata.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (metadata.isHDR)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text(
                    'HDR',
                    style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(
                icon: Icons.aspect_ratio,
                label: 'Resolution',
                value: is4K ? '4K ($resLabel)' : resLabel,
                accentColor: is4K ? AppColors.accentCyan : null,
              ),
              _buildBadge(
                icon: Icons.speed,
                label: 'Source FPS',
                value: '${metadata.fps.toStringAsFixed(metadata.fps % 1 == 0 ? 0 : 2)} FPS',
              ),
              _buildBadge(
                icon: Icons.timer,
                label: 'Duration',
                value: metadata.formattedDuration,
              ),
              _buildBadge(
                icon: Icons.video_file,
                label: 'Codec',
                value: metadata.codec,
              ),
              _buildBadge(
                icon: metadata.hasAudio ? Icons.volume_up : Icons.volume_off,
                label: 'Audio',
                value: metadata.hasAudio ? '${metadata.audioChannels}ch (${metadata.audioSampleRate ~/ 1000}kHz)' : 'None',
              ),
              _buildBadge(
                icon: Icons.folder,
                label: 'File Size',
                value: metadata.formattedFileSize,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
