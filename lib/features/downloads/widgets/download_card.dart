import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_widgets.dart';
import '../../../domain/entities/download_entity.dart';

class DownloadCard extends StatelessWidget {
  final DownloadEntity download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const DownloadCard({
    super.key,
    required this.download,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: download.thumbnailUrl != null
                  ? CachedNetworkImage(imageUrl: download.thumbnailUrl!, fit: BoxFit.cover)
                  : Container(color: AppColors.surfaceDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(download.mediaTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                download.status == DownloadStatus.downloading ||
                        download.status == DownloadStatus.queued
                    ? GradientProgressBar(value: download.progress, height: 5)
                    : download.status == DownloadStatus.processing
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            // Indeterminate — native mux/extract has no
                            // progress callback, so a filled bar would be
                            // misleading rather than just frozen.
                            child: const LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor: Colors.white12,
                              color: AppColors.accent,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: download.progress,
                              minHeight: 5,
                              backgroundColor: Colors.white12,
                              color: _statusColor(download.status),
                            ),
                          ),
                const SizedBox(height: 6),
                Text(
                  _statusLine(download),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(),
        ],
      ),
    );
  }

  Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.failed:
        return AppColors.error;
      case DownloadStatus.completed:
        return AppColors.success;
      case DownloadStatus.paused:
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }

  String _statusLine(DownloadEntity d) {
    switch (d.status) {
      case DownloadStatus.downloading:
        final totalStr = d.totalBytes > 0 ? Formatters.bytes(d.totalBytes) : 'Unknown Size';
        final receivedStr = Formatters.bytes(d.downloadedBytes);
        return '$receivedStr / $totalStr · '
            '${Formatters.speed(d.speedBytesPerSec)} · ETA ${Formatters.eta(d.eta)}';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.paused:
        final totalStr = d.totalBytes > 0 ? Formatters.bytes(d.totalBytes) : 'Unknown Size';
        return 'Paused · ${Formatters.bytes(d.downloadedBytes)} / $totalStr';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return d.errorMessage ?? 'Failed';
      case DownloadStatus.canceled:
        return 'Canceled';
      case DownloadStatus.processing:
        return 'Optimizing media... (Muxing/Transcoding)';
    }
  }

  Widget _actionButton() {
    switch (download.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return IconButton(icon: const Icon(CupertinoIcons.pause_circle), onPressed: onPause);
      case DownloadStatus.paused:
        return IconButton(icon: const Icon(CupertinoIcons.play_circle), onPressed: onResume);
      case DownloadStatus.failed:
        return IconButton(icon: const Icon(CupertinoIcons.arrow_clockwise), onPressed: onRetry);
      case DownloadStatus.completed:
        return const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success);
      case DownloadStatus.canceled:
        return IconButton(icon: const Icon(CupertinoIcons.arrow_clockwise), onPressed: onRetry);
      case DownloadStatus.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        );
    }
  }
}
