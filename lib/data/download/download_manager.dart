import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/download_repository.dart';
import 'mux_service.dart';
import 'transcode_service.dart';

const _tag = 'DownloadManager';

/// Owns all in-flight downloads: enqueues, respects a concurrency cap,
/// supports pause/resume via HTTP range requests, retries transient
/// failures, and persists progress through [DownloadRepository] so the UI
/// (via GetX controllers observing the repository's stream) always
/// reflects real state — including after the app is relaunched mid-download.
class DownloadManager {
  final DownloadRepository _repository;
  final MuxService _muxService;
  final TranscodeService _transcodeService;
  final Dio _dio;
  final SettingsService? _settingsService;
  final int _fallbackMaxConcurrent;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressAt = {};
  final Map<String, int> _lastProgressBytes = {};
  final List<String> _queue = [];
  final Set<String> _active = {};
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  DownloadManager(
    this._repository, {
    MuxService? muxService,
    TranscodeService? transcodeService,
    Dio? dio,
    SettingsService? settingsService,
    Connectivity? connectivity,
    int maxConcurrent = AppConstants.defaultMaxConcurrentDownloads,
  })  : _muxService = muxService ?? MuxService(),
        _transcodeService = transcodeService ?? TranscodeService(),
        _dio = dio ?? Dio(),
        _settingsService = settingsService,
        _fallbackMaxConcurrent = maxConcurrent,
        _connectivity = connectivity ?? Connectivity() {
    // When "Wi-Fi Only" is on and downloads are sitting queued waiting for
    // Wi-Fi, resume dispatch the moment Wi-Fi becomes available again.
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) => _tryStartNext());
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  // Read live so changing "Concurrent Downloads" in Settings takes effect
  // immediately instead of requiring an app restart.
  int get maxConcurrent => _settingsService?.concurrentDownloads ?? _fallbackMaxConcurrent;

  Future<void> enqueue(DownloadEntity download) async {
    AppLogger.i(_tag, 'enqueue ${download.id} "${download.mediaTitle}" (${download.format})');
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
      clearErrorMessage: true,
    ));
    if (!_queue.contains(id)) _queue.add(id);
    _tryStartNext();
  }

  /// Requeues any downloads left `queued`/`downloading` from a previous app
  /// session (e.g. the app was killed mid-download) so they resume instead
  /// of sitting stuck forever. Call once at startup.
  Future<void> resumeInterrupted() async {
    final active = await _repository.getActive();
    for (final entity in active) {
      // Paused is a deliberate user action — leave those alone. Only
      // `queued`/`downloading` were interrupted by the app being killed.
      if (entity.status == DownloadStatus.paused) continue;
      await _repository.save(entity.copyWith(status: DownloadStatus.queued));
      if (!_queue.contains(entity.id)) _queue.add(entity.id);
    }
    _tryStartNext();
  }

  Future<void> _tryStartNext() async {
    if (_settingsService?.wifiOnly ?? false) {
      final results = await _connectivity.checkConnectivity();
      final onWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (!onWifi) return; // stay queued until Wi-Fi (or ethernet) is back
    }
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
    AppLogger.i(
      _tag,
      'start $id: streamUrl=${_truncate(entity.streamUrl)}, '
      'requiresMuxing=${entity.audioStreamUrl != null}, needsAudioExtraction=${entity.needsAudioExtraction}',
    );

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
        // If audio needs extracting, leave headroom for that local step too
        // (no second network fetch, so less is needed than the mux case).
        progressWeight: entity.audioStreamUrl != null
            ? 0.45
            : (entity.needsAudioExtraction ? 0.7 : 1.0),
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

        // Native mux has no progress callback — surface a distinct status
        // instead of leaving the progress bar frozen near 90-100% looking stuck.
        entity = await _repository.getById(id);
        if (entity == null) return;
        await _repository.save(entity.copyWith(status: DownloadStatus.processing));

        final muxedPath = p.join(dir.path, '${entity.id}_final.mp4');
        finalPath = await _muxService.mux(
          videoPath: videoPath,
          audioPath: audioPath,
          outputPath: muxedPath,
        );
        // Clean up intermediates once mux succeeds.
        await _deleteQuietly(videoPath);
        await _deleteQuietly(audioPath);
      } else if (entity.needsAudioExtraction) {
        entity = await _repository.getById(id);
        if (entity == null) return;
        await _repository.save(entity.copyWith(status: DownloadStatus.processing));

        // Sources like Instagram/Facebook don't expose a separate
        // audio-only URL — `videoPath` is actually a full video file that
        // needs its audio track pulled out natively before it's a real
        // standalone audio file (see MuxService.extractAudio).
        final extractedPath = p.join(dir.path, '${entity.id}_final.m4a');
        finalPath = await _muxService.extractAudio(
          sourcePath: videoPath,
          outputPath: extractedPath,
        );
        await _deleteQuietly(videoPath);
      }

      // Check for transcoding requirement
      if (entity.type == MediaType.video) {
        entity = await _repository.getById(id);
        if (entity == null) return;
        await _repository.save(entity.copyWith(status: DownloadStatus.processing));
        finalPath = await _transcodeService.ensureIosCompatibility(finalPath);
      }

      entity = await _repository.getById(id);
      if (entity == null) return;
      await _repository.save(entity.copyWith(
        status: DownloadStatus.completed,
        finishedAt: DateTime.now(),
        downloadedBytes: entity.totalBytes,
      ));
      AppLogger.i(_tag, 'completed $id -> $finalPath');
      // Callers (e.g. ImportController) are responsible for indexing the
      // finished file into MediaRepository + moving it to the chosen save
      // destination (Photos/Files) — that's a library concern, not a
      // download-transport concern, so it stays out of this class.
      _finalPaths[id] = finalPath;
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        // Paused or canceled — status was already set by pause()/cancel().
        AppLogger.d(_tag, '$id canceled/paused');
        return;
      }
      AppLogger.e(_tag, '$id network error', e, st);
      await _handleFailure(id, e.message ?? 'Network error');
    } catch (e, st) {
      AppLogger.e(_tag, '$id failed', e, st);
      await _handleFailure(id, e.toString());
    } finally {
      _cancelTokens.remove(id);
      _active.remove(id);
      _tryStartNext();
    }
  }

  final Map<String, String> _finalPaths = {};
  String? finalPathFor(String id) => _finalPaths[id];

  /// CDN stream URLs carry long signed query strings — truncate for logs so
  /// they're skimmable (and don't dump a valid signed URL into logs in
  /// full) while still showing enough to identify the host/path.
  String _truncate(String url, {int maxLength = 100}) =>
      url.length <= maxLength ? url : '${url.substring(0, maxLength)}…';

  /// Deletes an intermediate file, logging (not swallowing) failures so
  /// leftover `.mp4`/`.m4a` files from failed cleanup are at least visible
  /// instead of silently accumulating on disk.
  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.w(_tag, 'failed to delete intermediate file $path: $e');
    }
  }

  Future<void> _handleFailure(String id, String message) async {
    final entity = await _repository.getById(id);
    if (entity == null) return;
    if (entity.retryCount < AppConstants.maxRetryAttempts) {
      AppLogger.w(
        _tag,
        '$id retrying (attempt ${entity.retryCount + 1}/${AppConstants.maxRetryAttempts}): $message',
      );
      await _repository.save(entity.copyWith(
        status: DownloadStatus.queued,
        retryCount: entity.retryCount + 1,
        errorMessage: message,
      ));
      // Don't await the backoff here — that would hold this download's
      // concurrency slot idle for the whole delay, since the caller's
      // `finally` block (which frees the slot) can't run until this
      // returns. Schedule the requeue in the background instead so other
      // queued downloads can use the slot immediately.
      unawaited(Future.delayed(AppConstants.retryBackoff, () {
        if (!_queue.contains(id)) _queue.add(id);
        _tryStartNext();
      }));
    } else {
      AppLogger.e(_tag, '$id gave up after ${AppConstants.maxRetryAttempts} attempts: $message');
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
    final entity = await _repository.getById(id);
    if (entity == null) return;

    // Server didn't send content-length (effectiveTotal == 0) — fall back
    // to the entity's previously known total instead of bailing out and
    // leaving progress/speed/ETA frozen for this segment.
    final resolvedTotal = effectiveTotal > 0 ? effectiveTotal : entity.totalBytes;
    if (resolvedTotal <= 0) return;

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

    final overallFraction =
        progressOffset + (effectiveReceived / resolvedTotal) * progressWeight;
    final overallTotal = entity.totalBytes > 0 ? entity.totalBytes : resolvedTotal;
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
