import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/media_save_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/error_messages.dart';
import '../../data/download/download_manager.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/media_repository.dart';

const _tag = 'DownloadQueueController';

// Statuses where a download is still "in flight" and needs to be
// canceled (not just deleted) before its record/files are removed.
const _cancelableStatuses = {
  DownloadStatus.queued,
  DownloadStatus.downloading,
  DownloadStatus.paused,
  DownloadStatus.processing,
  DownloadStatus.saving,
};

/// Owns the Download Queue screen's state, and — just as importantly —
/// performs the "index into Library" step once a download finishes: moving
/// the file to the user's chosen save destination and creating the
/// corresponding [MediaEntity]. This is deliberately not inside
/// [DownloadManager], which only knows about moving bytes; deciding what a
/// finished download *means* to the rest of the app is a library/UI
/// concern.
class DownloadQueueController extends GetxController {
  final DownloadRepository _downloadRepository = Get.find<DownloadRepository>();
  final MediaRepository _mediaRepository = Get.find<MediaRepository>();
  final DownloadManager _downloadManager = Get.find<DownloadManager>();
  final MediaSaveService _saveService = MediaSaveService();
  final _dio = Dio();

  final downloads = <DownloadEntity>[].obs;
  StreamSubscription<List<DownloadEntity>>? _downloadsSub;

  // In-memory guard so a completed-but-not-yet-indexed download isn't
  // re-triggered on every `watchAll` emission while indexing is in flight
  // (indexed is only persisted `true` once indexing actually succeeds).
  final Set<String> _indexing = {};

  @override
  void onInit() {
    super.onInit();
    _downloadsSub = _downloadRepository.watchAll().listen((all) {
      downloads.value = all;
      for (final d in all) {
        if (d.status == DownloadStatus.completed && !d.indexed && !_indexing.contains(d.id)) {
          _indexCompletedDownload(d);
        }
      }
    });
  }

  @override
  void onClose() {
    _downloadsSub?.cancel();
    super.onClose();
  }

  Future<void> pause(String id) => _downloadManager.pause(id);
  Future<void> resume(String id) => _downloadManager.resume(id);
  Future<void> cancel(String id) => _downloadManager.cancel(id);
  Future<void> retry(String id) => _downloadManager.retry(id);

  /// Removes a download entirely: cancels it first if still in flight,
  /// deletes its file(s) from disk, removes the matching Library entry
  /// (same id as the download — see `_indexCompletedDownload`) so it also
  /// disappears from Home/Library, then removes the download record
  /// itself. Called from the Downloads screen's swipe-to-delete.
  Future<void> delete(String id) async {
    final download = await _downloadRepository.getById(id);
    if (download == null) return;

    if (_cancelableStatuses.contains(download.status)) {
      await _downloadManager.cancel(id);
    }

    if (download.savedFilePath != null) {
      await _deleteFileQuietly(download.savedFilePath!);
    }
    // Covers a download that never finished indexing — the file may still
    // be sitting wherever DownloadManager left it, not yet at savedFilePath.
    final stagedPath = _downloadManager.finalPathFor(id);
    if (stagedPath != null && stagedPath != download.savedFilePath) {
      await _deleteFileQuietly(stagedPath);
    }

    final media = await _mediaRepository.getById(id);
    if (media != null) {
      if (media.path != download.savedFilePath) {
        await _deleteFileQuietly(media.path);
      }
      await _mediaRepository.delete(id);
    }

    await _downloadRepository.delete(id);
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort — a missing/already-gone file shouldn't block removing
      // the record itself.
    }
  }

  Future<void> _indexCompletedDownload(DownloadEntity download) async {
    _indexing.add(download.id);
    try {
      final sourcePath = _downloadManager.finalPathFor(download.id);
      if (sourcePath == null || !await File(sourcePath).exists()) {
        await _downloadRepository.save(download.copyWith(
          errorMessage: 'Downloaded file went missing before it could be saved to your library.',
        ));
        // Deliberately not removed from `_indexing` here — status stays
        // `completed`/`indexed: false`, which is exactly what re-triggers
        // this method on every `watchAll` emission. Leaving the id marked
        // stops that immediate retry loop; it still retries on next app
        // launch (`_indexing` is in-memory, reset on restart).
        return;
      }

      // Distinct from DownloadStatus.processing (native mux/extraction) —
      // this is the "moving to its Photos/Files destination" phase, so the
      // status line can say something accurate instead of a generic
      // "processing" that would otherwise cover both.
      await _downloadRepository.save(download.copyWith(status: DownloadStatus.saving));

      final fileName = '${download.mediaTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}'
          '.${download.format}';

      bool photosSaveFailed = false;
      if (download.saveDestination == SaveDestination.photos) {
        final savedToPhotos = await _saveService.saveToPhotos(
          sourcePath: sourcePath,
          type: download.type,
          title: download.mediaTitle,
        );
        photosSaveFailed = !savedToPhotos;
        if (photosSaveFailed) {
          AppLogger.w(_tag, '${download.id} failed to save to Photos (permission denied?)');
        }
      }
      // Harbor also keeps its own Documents/Files copy regardless of
      // destination, so playback/offline access doesn't depend on Photos
      // permissions later.
      final finalPath = await _saveService.saveToFiles(sourcePath: sourcePath, fileName: fileName);

      final thumbnailPath = await _cacheThumbnail(download);

      final media = MediaEntity(
        // Same id as the download it came from — lets `delete()` find and
        // remove the corresponding library entry without a separate
        // lookup/index.
        id: download.id,
        title: download.mediaTitle,
        thumbnailPath: thumbnailPath,
        type: download.type,
        duration: download.duration,
        sizeBytes: download.totalBytes,
        resolution: download.resolution,
        format: download.format,
        saveLocation: download.saveDestination,
        path: finalPath,
        createdAt: DateTime.now(),
        source: MediaSource.unknown,
      );

      await _mediaRepository.save(media);
      // Only mark indexed now that the file is actually saved and the
      // library entry exists — marking it earlier meant a save failure
      // could make a completed download silently vanish with no retry path.
      await _downloadRepository.save(download.copyWith(
        status: DownloadStatus.completed,
        indexed: true,
        clearErrorMessage: true,
        savedFilePath: finalPath,
      ));
      // Only clear the guard on success — see the note above on why a
      // failure deliberately leaves the id in `_indexing` instead of using
      // a blanket `finally`.
      _indexing.remove(download.id);
    } catch (e) {
      // Indexing failure shouldn't crash the queue; the download itself
      // succeeded. Surface it via errorMessage so it's visible in the
      // queue instead of silently disappearing; `indexed` stays false so
      // it's retried on the next app session (not immediately — id stays
      // in `_indexing` for the rest of this session, see above). Revert
      // status back to completed too — it was flipped to `saving` above,
      // and getting stuck there would show an indeterminate spinner forever.
      await _downloadRepository.save(download.copyWith(
        status: DownloadStatus.completed,
        errorMessage: 'Couldn\'t save to your library: ${friendlyMessage(e)}',
      ));
    }
  }

  Future<String?> _cacheThumbnail(DownloadEntity download) async {
    if (download.thumbnailUrl == null) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, AppConstants.thumbnailCacheDir));
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = p.join(dir.path, '${download.id}.jpg');
      await _dio.download(download.thumbnailUrl!, path);
      return path;
    } catch (_) {
      return null;
    }
  }
}
