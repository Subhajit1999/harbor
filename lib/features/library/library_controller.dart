import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/folder_repository.dart';
import '../../domain/repositories/media_repository.dart';

class LibraryController extends GetxController {
  final MediaRepository _mediaRepository = Get.find<MediaRepository>();
  final FolderRepository _folderRepository = Get.find<FolderRepository>();
  final _uuid = const Uuid();

  final allMedia = <MediaEntity>[].obs;
  final folders = <FolderEntity>[].obs;
  StreamSubscription<List<MediaEntity>>? _mediaSub;
  StreamSubscription<List<FolderEntity>>? _foldersSub;

  @override
  void onInit() {
    super.onInit();
    _mediaSub = _mediaRepository.watchAll().listen((all) => allMedia.value = all);
    _foldersSub = _folderRepository.watchAll().listen((all) => folders.value = all);
  }

  @override
  void onClose() {
    _mediaSub?.cancel();
    _foldersSub?.cancel();
    super.onClose();
  }

  List<MediaEntity> get videos =>
      allMedia.where((m) => m.type == MediaType.video).toList();

  List<MediaEntity> get audio => allMedia.where((m) => m.type == MediaType.audio).toList();

  List<MediaEntity> get favorites => allMedia.where((m) => m.favorite).toList();

  List<MediaEntity> mediaInFolder(String folderId) =>
      allMedia.where((m) => m.folderId == folderId).toList();

  Future<void> toggleFavorite(String id) => _mediaRepository.toggleFavorite(id);

  Future<void> rename(String id, String title) => _mediaRepository.rename(id, title);

  Future<void> delete(MediaEntity media) async {
    final file = File(media.path);
    if (await file.exists()) await file.delete();
    await _mediaRepository.delete(media.id);
  }

  Future<void> moveToFolder(String id, String? folderId) =>
      _mediaRepository.moveToFolder(id, folderId);

  Future<void> createFolder(String name) async {
    await _folderRepository.save(FolderEntity(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> share(MediaEntity media) async {
    await Share.shareXFiles([XFile(media.path)], text: media.title);
  }

  Future<void> export(MediaEntity media) async {
    // "Export" reuses the share sheet — on iOS this surfaces "Save to
    // Files" as one of the share destinations, which covers the product
    // spec's export requirement without a bespoke file-picker integration.
    await share(media);
  }
}
