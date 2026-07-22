import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/download_repository.dart';
import 'mux_service.dart';

/// Owns all in-flight downloads: enqueues, respects a concurrency cap,
/// supports pause/resume via HTTP range requests, retries transient
/// failures, and persists progress through [DownloadRepository] so the UI
/// (via GetX controllers observing the repository's stream) always
/// reflects real state — including after the app is relaunched mid-download.
class DownloadManager {
  final DownloadRepository _repository;
  final MuxService _muxService;
  final Dio _dio;

  final int maxConcurrent;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressAt = {};
  final Map<String, int> _lastProgressBytes = {};
  final List<String> _queue = [];
  final Set<String> _active = {};

  DownloadManager(
    this._repository, {
    MuxService? muxService,
    Dio? dio,
    this.maxConcurrent = AppConstants.defaultMaxConcurrentDownloads,
  })  : _muxService = muxService ?? MuxService(),
        _dio = dio ?? Dio();

  Future<void> enqueue(DownloadEntity download) async {
    await _repository.save(download.copyWith(status: DownloadStatus.queued));
    _queue.add(download.id);
    _tryStartNext();
  }

  Future<void> pause(String id) async {
    _cancelTokens[id]?.cancel('paused');
    final entity = await _repository.getById(id);
    if (entity != null) {
      await _repository.save(entity.copyWith(status: DownloadStatus.paused));
    }
    _active.remove(id);
    _tryStartNext();
  }

  Future<void> resume(String id) async {
    final entity = await _repository.getById(id);
    if (entity == null) return;
    await _repository.save(entity.copyWith(status: DownloadStatus.queued));
    if (!_queue.contains(id)) _queue.add(id);
    _tryStartNext();
  }

  Future<void> cancel(String id) async {
    _cancelTokens[id]?.cancel('canceled');
    _queue.remove(id);
    _active.remove(id);
    final entity = await _repository.getById(id);
    if (entity != null) {
      await _repository.save(entity.copyWith(status: DownloadStatus.canceled));
    }
  }

  Future<void> retry(String id) async {
    final entity = await _repository.getById(id);
    if (entity == null) return;
    await _repository.save(entity.copyWith(
      status: DownloadStatus.queued,
      retryCount: entity.retryCount + 1,
      errorMessage: null,
    ));
    if (!_queue.contains(id)) _queue.add(id);
    _tryStartNext();
  }

  void _tryStartNext() {
    while (_active.length < maxConcurrent && _queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      _active.add(id);
      unawaited(_runDownload(id));
    }
  }

  Future<Directory> _downloadDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.mediaStorageDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _runDownload(String id) async {
    var entity = await _repository.getById(id);
    if (entity == null) {
      _active.remove(id);
      _tryStartNext();
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      await _repository.save(entity.copyWith(status: DownloadStatus.downloading));

      final dir = await _downloadDir();
      final safeName = '${entity.id}.${entity.format}';
      final videoPath = p.join(dir.path, safeName);

      await _downloadFile(
        url: entity.streamUrl,
        savePath: videoPath,
        id: id,
        cancelToken: cancelToken,
        // If audio needs muxing, the video-only track is only half the
        // total — leave headroom for the audio download + mux step below.
        progressWeight: entity.audioStreamUrl != null ? 0.45 : 1.0,
      );

      var finalPath = videoPath;

      if (entity.audioStreamUrl != null) {
        final audioPath = p.join(dir.path, '${entity.id}_audio.m4a');
        await _downloadFile(
          url: entity.audioStreamUrl!,
          savePath: audioPath,
          id: id,
          cancelToken: cancelToken,
          progressWeight: 0.45,
          progressOffset: 0.45,
        );

        final muxedPath = p.join(dir.path, '${entity.id}_final.mp4');
        finalPath = await _muxService.mux(
          videoPath: videoPath,
          audioPath: audioPath,
          outputPath: muxedPath,
        );
        // Clean up intermediates once mux succeeds.
        await File(videoPath).delete().catchError((_) => File(videoPath));
        await File(audioPath).delete().catchError((_) => File(audioPath));
      }

      entity = await _repository.getById(id);
      if (entity == null) return;
      await _repository.save(entity.copyWith(
        status: DownloadStatus.completed,
        finishedAt: DateTime.now(),
        downloadedBytes: entity.totalBytes,
      ));
      // Callers (e.g. ImportController) are responsible for indexing the
      // finished file into MediaRepository + moving it to the chosen save
      // destination (Photos/Files) — that's a library concern, not a
      // download-transport concern, so it stays out of this class.
      _finalPaths[id] = finalPath;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Paused or canceled — status was already set by pause()/cancel().
        return;
      }
      await _handleFailure(id, e.message ?? 'Network error');
    } catch (e) {
      await _handleFailure(id, e.toString());
    } finally {
      _cancelTokens.remove(id);
      _active.remove(id);
      _tryStartNext();
    }
  }

  final Map<String, String> _finalPaths = {};
  String? finalPathFor(String id) => _finalPaths[id];

  Future<void> _handleFailure(String id, String message) async {
    final entity = await _repository.getById(id);
    if (entity == null) return;
    if (entity.retryCount < AppConstants.maxRetryAttempts) {
      await _repository.save(entity.copyWith(
        status: DownloadStatus.queued,
        retryCount: entity.retryCount + 1,
        errorMessage: message,
      ));
      await Future.delayed(AppConstants.retryBackoff);
      if (!_queue.contains(id)) _queue.add(id);
      _tryStartNext();
    } else {
      await _repository.save(entity.copyWith(
        status: DownloadStatus.failed,
        errorMessage: message,
      ));
    }
  }

  /// Streams the response manually rather than using `Dio.download()`.
  ///
  /// This matters for pause/resume: `Dio.download()` always writes a fresh
  /// file, so replaying it with a `Range` header would overwrite the
  /// already-downloaded bytes with just the new tail portion, silently
  /// corrupting the resumed file. Streaming lets us open the file in
  /// append mode and only ever add new bytes after the existing ones.
  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required String id,
    required CancelToken cancelToken,
    double progressWeight = 1.0,
    double progressOffset = 0.0,
  }) async {
    final file = File(savePath);
    var existingBytes = 0;
    if (await file.exists()) {
      existingBytes = await file.length();
    }

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: existingBytes > 0 ? {'range': 'bytes=$existingBytes-'} : null,
      ),
    );

    // A 200 (not 206 Partial Content) means the server ignored our Range
    // request — start over rather than appending onto a mismatched offset.
    final serverHonoredRange = response.statusCode == 206;
    final effectiveExisting = serverHonoredRange ? existingBytes : 0;
    final raf = await file.open(mode: serverHonoredRange ? FileMode.append : FileMode.write);

    final contentLengthHeader = response.data!.headers['content-length']?.first;
    final chunkTotal = int.tryParse(contentLengthHeader ?? '') ?? 0;
    final effectiveTotal = effectiveExisting + chunkTotal;

    var received = 0;
    try {
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        await _reportProgress(
          id: id,
          effectiveReceived: effectiveExisting + received,
          effectiveTotal: effectiveTotal,
          progressWeight: progressWeight,
          progressOffset: progressOffset,
        );
      }
    } finally {
      await raf.close();
    }
  }

  Future<void> _reportProgress({
    required String id,
    required int effectiveReceived,
    required int effectiveTotal,
    required double progressWeight,
    required double progressOffset,
  }) async {
    if (effectiveTotal <= 0) return;

    final now = DateTime.now();
    final lastAt = _lastProgressAt[id];
    final lastBytes = _lastProgressBytes[id] ?? 0;
    double speed = 0;
    if (lastAt != null) {
      final elapsed = now.difference(lastAt).inMilliseconds / 1000.0;
      if (elapsed > 0.3) {
        speed = (effectiveReceived - lastBytes) / elapsed;
        _lastProgressAt[id] = now;
        _lastProgressBytes[id] = effectiveReceived;
      }
    } else {
      _lastProgressAt[id] = now;
      _lastProgressBytes[id] = effectiveReceived;
    }

    final entity = await _repository.getById(id);
    if (entity == null) return;

    final overallFraction =
        progressOffset + (effectiveReceived / effectiveTotal) * progressWeight;
    final overallTotal = entity.totalBytes > 0 ? entity.totalBytes : effectiveTotal;
    final overallDownloaded = (overallFraction * overallTotal).round();

    Duration? eta;
    if (speed > 0) {
      final remaining = overallTotal - overallDownloaded;
      eta = Duration(seconds: (remaining / speed).round());
    }

    await _repository.save(entity.copyWith(
      downloadedBytes: overallDownloaded,
      speedBytesPerSec: speed > 0 ? speed : entity.speedBytesPerSec,
      eta: eta,
    ));
  }
}
