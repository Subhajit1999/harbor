import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/media_save_service.dart';
import '../../core/utils/error_messages.dart';
import '../../data/download/download_manager.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/media_repository.dart';

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
  final _uuid = const Uuid();
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

  Future<void> _indexCompletedDownload(DownloadEntity download) async {
    _indexing.add(download.id);
    try {
      final sourcePath = _downloadManager.finalPathFor(download.id);
      if (sourcePath == null || !await File(sourcePath).exists()) {
        await _downloadRepository.save(download.copyWith(
          errorMessage: 'Downloaded file went missing before it could be saved to your library.',
        ));
        return;
      }

      // Distinct from DownloadStatus.processing (native mux/extraction) —
      // this is the "moving to its Photos/Files destination" phase, so the
      // status line can say something accurate instead of a generic
      // "processing" that would otherwise cover both.
      await _downloadRepository.save(download.copyWith(status: DownloadStatus.saving));

      final fileName = '${download.mediaTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}'
          '.${download.format}';

      String finalPath = sourcePath;
      if (download.saveDestination == SaveDestination.photos) {
        await _saveService.saveToPhotos(
          sourcePath: sourcePath,
          type: download.type,
          title: download.mediaTitle,
        );
        // Photos ingests a copy into the system library; Harbor still keeps
        // its own local copy (below) so playback/offline access doesn't
        // depend on Photos permissions later.
        finalPath = await _saveService.saveToFiles(sourcePath: sourcePath, fileName: fileName);
      } else {
        finalPath = await _saveService.saveToFiles(sourcePath: sourcePath, fileName: fileName);
      }

      final thumbnailPath = await _cacheThumbnail(download);

      final media = MediaEntity(
        id: _uuid.v4(),
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
    } catch (e) {
      // Indexing failure shouldn't crash the queue; the download itself
      // succeeded. Surface it via errorMessage so it's visible in the
      // queue instead of silently disappearing; `indexed` stays false so
      // it's retried on the next app session. Revert status back to
      // completed too — it was flipped to `saving` above, and getting
      // stuck there would show an indeterminate spinner forever.
      await _downloadRepository.save(download.copyWith(
        status: DownloadStatus.completed,
        errorMessage: 'Couldn\'t save to your library: ${friendlyMessage(e)}',
      ));
    } finally {
      _indexing.remove(download.id);
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
