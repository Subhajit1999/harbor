import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// Domain representation of a single queued/in-flight/completed download.
class DownloadEntity extends Equatable {
  final String id;
  final String mediaTitle;
  final String? thumbnailUrl;
  final String sourceUrl;
  final String streamUrl;
  final String? audioStreamUrl; // set when video+audio need muxing (adaptive)
  final bool needsAudioExtraction; // set when streamUrl is a video that needs its audio track pulled out
  final MediaType type;
  final String format;
  final String? resolution;
  final Duration duration;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final double speedBytesPerSec;
  final Duration? eta;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int retryCount;
  final String? errorMessage;
  final SaveDestination saveDestination;
  final bool indexed;

  const DownloadEntity({
    required this.id,
    required this.mediaTitle,
    this.thumbnailUrl,
    required this.sourceUrl,
    required this.streamUrl,
    this.audioStreamUrl,
    this.needsAudioExtraction = false,
    required this.type,
    required this.format,
    this.resolution,
    this.duration = Duration.zero,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.speedBytesPerSec = 0,
    this.eta,
    required this.startedAt,
    this.finishedAt,
    this.retryCount = 0,
    this.errorMessage,
    required this.saveDestination,
    this.indexed = false,
  });

  double get progress => totalBytes == 0 ? 0 : downloadedBytes / totalBytes;

  DownloadEntity copyWith({
    int? downloadedBytes,
    DownloadStatus? status,
    double? speedBytesPerSec,
    Duration? eta,
    DateTime? finishedAt,
    int? retryCount,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? totalBytes,
    bool? indexed,
  }) {
    return DownloadEntity(
      id: id,
      mediaTitle: mediaTitle,
      thumbnailUrl: thumbnailUrl,
      sourceUrl: sourceUrl,
      streamUrl: streamUrl,
      audioStreamUrl: audioStreamUrl,
      needsAudioExtraction: needsAudioExtraction,
      type: type,
      format: format,
      resolution: resolution,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      eta: eta ?? this.eta,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      saveDestination: saveDestination,
      indexed: indexed ?? this.indexed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        mediaTitle,
        thumbnailUrl,
        sourceUrl,
        streamUrl,
        audioStreamUrl,
        needsAudioExtraction,
        type,
        format,
        resolution,
        duration,
        totalBytes,
        downloadedBytes,
        status,
        speedBytesPerSec,
        eta,
        startedAt,
        finishedAt,
        retryCount,
        errorMessage,
        saveDestination,
        indexed,
      ];
}
