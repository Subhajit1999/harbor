import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../data/resolvers/resolver_registry.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/media_repository.dart';

class HomeController extends GetxController {
  final MediaRepository _mediaRepository = Get.find<MediaRepository>();
  final DownloadRepository _downloadRepository = Get.find<DownloadRepository>();
  final ResolverRegistry _resolverRegistry = Get.find<ResolverRegistry>();

  final recentImports = <MediaEntity>[].obs;
  final activeDownloads = <DownloadEntity>[].obs;
  final totalStorageBytes = 0.obs;
  final clipboardLink = RxnString();
  StreamSubscription<List<MediaEntity>>? _mediaSub;
  StreamSubscription<List<DownloadEntity>>? _downloadsSub;

  @override
  void onInit() {
    super.onInit();
    _mediaSub = _mediaRepository.watchAll().listen((all) {
      recentImports.value = all.take(8).toList();
    });
    _downloadsSub = _downloadRepository.watchAll().listen((all) {
      activeDownloads.value = all
          .where((d) =>
              d.status.name == 'downloading' ||
              d.status.name == 'queued' ||
              d.status.name == 'paused')
          .toList();
    });
    _refreshStorage();
    checkClipboard();
  }

  @override
  void onClose() {
    _mediaSub?.cancel();
    _downloadsSub?.cancel();
    super.onClose();
  }

  Future<void> _refreshStorage() async {
    totalStorageBytes.value = await _mediaRepository.totalStorageBytes();
  }

  /// Peeks the clipboard for a supported link so Home can offer a
  /// "Paste Link" quick action with the URL pre-filled, without requiring
  /// the user to open the Import screen first.
  Future<void> checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && _resolverRegistry.isSupported(text)) {
      clipboardLink.value = text;
    } else {
      clipboardLink.value = null;
    }
  }
}
