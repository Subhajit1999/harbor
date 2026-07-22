import 'package:isar/isar.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/download_entity.dart';

part 'download_model.g.dart';

@collection
class DownloadModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  late String mediaTitle;
  String? thumbnailUrl;
  late String sourceUrl;
  late String streamUrl;
  String? audioStreamUrl;
  bool needsAudioExtraction = false;

  @enumerated
  late MediaType type;

  late String format;
  String? resolution;
  int durationMs = 0;
  late int totalBytes;
  int downloadedBytes = 0;

  @Index()
  @enumerated
  late DownloadStatus status;

  double speedBytesPerSec = 0;
  int? etaSeconds;
  late DateTime startedAt;
  DateTime? finishedAt;
  int retryCount = 0;
  String? errorMessage;

  @enumerated
  late SaveDestination saveDestination;

  bool indexed = false;

  DownloadEntity toEntity() => DownloadEntity(
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
        duration: Duration(milliseconds: durationMs),
        totalBytes: totalBytes,
        downloadedBytes: downloadedBytes,
        status: status,
        speedBytesPerSec: speedBytesPerSec,
        eta: etaSeconds == null ? null : Duration(seconds: etaSeconds!),
        startedAt: startedAt,
        finishedAt: finishedAt,
        retryCount: retryCount,
        errorMessage: errorMessage,
        saveDestination: saveDestination,
        indexed: indexed,
      );

  static DownloadModel fromEntity(DownloadEntity e) => DownloadModel()
    ..id = e.id
    ..mediaTitle = e.mediaTitle
    ..thumbnailUrl = e.thumbnailUrl
    ..sourceUrl = e.sourceUrl
    ..streamUrl = e.streamUrl
    ..audioStreamUrl = e.audioStreamUrl
    ..needsAudioExtraction = e.needsAudioExtraction
    ..type = e.type
    ..format = e.format
    ..resolution = e.resolution
    ..durationMs = e.duration.inMilliseconds
    ..totalBytes = e.totalBytes
    ..downloadedBytes = e.downloadedBytes
    ..status = e.status
    ..speedBytesPerSec = e.speedBytesPerSec
    ..etaSeconds = e.eta?.inSeconds
    ..startedAt = e.startedAt
    ..finishedAt = e.finishedAt
    ..retryCount = e.retryCount
    ..errorMessage = e.errorMessage
    ..saveDestination = e.saveDestination
    ..indexed = e.indexed;
}
