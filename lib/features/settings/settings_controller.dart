import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
import '../../domain/repositories/media_repository.dart';

class SettingsController extends GetxController {
  final SettingsService _settingsService = Get.find<SettingsService>();
  final MediaRepository _mediaRepository = Get.find<MediaRepository>();

  final wifiOnly = false.obs;
  final concurrentDownloads = AppConstants.defaultMaxConcurrentDownloads.obs;
  final autoResume = true.obs;
  final saveDestination = SaveDestination.askEveryTime.obs;
  final defaultPlaybackSpeed = 1.0.obs;
  final rememberPosition = true.obs;

  final libraryStorageBytes = 0.obs;
  final cacheBytes = 0.obs;

  @override
  void onInit() {
    super.onInit();
    wifiOnly.value = _settingsService.wifiOnly;
    concurrentDownloads.value = _settingsService.concurrentDownloads;
    autoResume.value = _settingsService.autoResume;
    saveDestination.value = _settingsService.saveDestination;
    defaultPlaybackSpeed.value = _settingsService.defaultPlaybackSpeed;
    rememberPosition.value = _settingsService.rememberPosition;
    _refreshStorage();
  }

  Future<void> _refreshStorage() async {
    libraryStorageBytes.value = await _mediaRepository.totalStorageBytes();
    cacheBytes.value = await _cacheDirSize();
  }

  Future<int> _cacheDirSize() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.thumbnailCacheDir));
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.thumbnailCacheDir));
    if (await dir.exists()) await dir.delete(recursive: true);
    await _refreshStorage();
  }

  Future<void> clearHistory() => _settingsService.clearHistory();

  void setWifiOnly(bool value) {
    wifiOnly.value = value;
    _settingsService.wifiOnly = value;
  }

  void setConcurrentDownloads(int value) {
    concurrentDownloads.value = value;
    _settingsService.concurrentDownloads = value;
  }

  void setAutoResume(bool value) {
    autoResume.value = value;
    _settingsService.autoResume = value;
  }

  void setSaveDestination(SaveDestination value) {
    saveDestination.value = value;
    _settingsService.saveDestination = value;
  }

  void setDefaultPlaybackSpeed(double value) {
    defaultPlaybackSpeed.value = value;
    _settingsService.defaultPlaybackSpeed = value;
  }

  void setRememberPosition(bool value) {
    rememberPosition.value = value;
    _settingsService.rememberPosition = value;
  }
}
