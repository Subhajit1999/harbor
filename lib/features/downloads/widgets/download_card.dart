import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
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

  bool get _isIndeterminate =>
      download.status == DownloadStatus.processing || download.status == DownloadStatus.saving;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: download.thumbnailUrl != null
                      ? CachedNetworkImage(imageUrl: download.thumbnailUrl!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surfaceDark,
                          child: const Icon(CupertinoIcons.film, color: AppColors.textSecondaryDark),
                        ),
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 6),
                    _StatusPill(status: download.status),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _isIndeterminate
                          ? const LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor: Colors.white12,
                              color: AppColors.accent,
                            )
                          : (download.status == DownloadStatus.downloading ||
                                  download.status == DownloadStatus.queued)
                              ? GradientProgressBar(value: download.progress, height: 5)
                              : LinearProgressIndicator(
                                  value: download.progress,
                                  minHeight: 5,
                                  backgroundColor: Colors.white12,
                                  color: _statusColor(download.status),
                                ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusLine(download),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: download.status == DownloadStatus.failed
                            ? AppColors.error
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _actionButton(),
            ],
          ),
          if (download.status == DownloadStatus.completed && download.savedFilePath != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => OpenFilex.open(download.savedFilePath!),
                icon: const Icon(CupertinoIcons.folder_open, size: 16, color: AppColors.accent),
                label: const Text('Open', style: TextStyle(color: AppColors.accent)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
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
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
      case DownloadStatus.processing:
      case DownloadStatus.saving:
      case DownloadStatus.canceled:
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
        return 'Waiting to start...';
      case DownloadStatus.paused:
        final totalStr = d.totalBytes > 0 ? Formatters.bytes(d.totalBytes) : 'Unknown Size';
        return 'Paused · ${Formatters.bytes(d.downloadedBytes)} / $totalStr';
      case DownloadStatus.completed:
        return 'Completed · ${Formatters.bytes(d.totalBytes)}';
      case DownloadStatus.failed:
        return d.errorMessage ?? 'Something went wrong. Try again.';
      case DownloadStatus.canceled:
        return 'Canceled';
      case DownloadStatus.processing:
        if (d.audioStreamUrl != null) return 'Combining video and audio...';
        if (d.needsAudioExtraction) return 'Extracting audio...';
        return 'Processing...';
      case DownloadStatus.saving:
        return 'Saving to your library...';
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
      case DownloadStatus.saving:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  final DownloadStatus status;

  const _StatusPill({required this.status});

  ({IconData icon, Color color, String label}) _spec() {
    switch (status) {
      case DownloadStatus.queued:
        return (icon: CupertinoIcons.clock, color: AppColors.textSecondaryDark, label: 'Queued');
      case DownloadStatus.downloading:
        return (icon: CupertinoIcons.arrow_down_circle, color: AppColors.accent, label: 'Downloading');
      case DownloadStatus.paused:
        return (icon: CupertinoIcons.pause_circle, color: AppColors.warning, label: 'Paused');
      case DownloadStatus.processing:
        return (icon: CupertinoIcons.gear_alt, color: AppColors.accent, label: 'Processing');
      case DownloadStatus.saving:
        return (icon: CupertinoIcons.tray_arrow_down, color: AppColors.accent, label: 'Saving');
      case DownloadStatus.completed:
        return (icon: CupertinoIcons.checkmark_circle, color: AppColors.success, label: 'Completed');
      case DownloadStatus.failed:
        return (icon: CupertinoIcons.exclamationmark_circle, color: AppColors.error, label: 'Failed');
      case DownloadStatus.canceled:
        return (icon: CupertinoIcons.xmark_circle, color: AppColors.textSecondaryDark, label: 'Canceled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 12, color: spec.color),
          const SizedBox(width: 4),
          Text(spec.label, style: TextStyle(fontSize: 11, color: spec.color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
