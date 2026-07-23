import 'package:get/get.dart';
import '../../data/download/download_manager.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/repositories/folder_repository_impl.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/resolvers/resolver_registry.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/folder_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../services/isar_service.dart';
import '../services/settings_service.dart';

/// Composition root. GetX plays the role Riverpod/GetIt would in the
/// original architecture note — one system for state, DI, and routing
/// rather than three overlapping ones. Everything here is `permanent: true`
/// because these are app-lifetime singletons (DB connection, download
/// manager) that must never be disposed while the app is running.
class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // Services (already initialized in main() before runApp)
    Get.put<IsarService>(Get.find<IsarService>(), permanent: true);
    Get.put<SettingsService>(Get.find<SettingsService>(), permanent: true);

    // Repositories
    Get.put<MediaRepository>(
      MediaRepositoryImpl(Get.find<IsarService>()),
      permanent: true,
    );
    Get.put<DownloadRepository>(
      DownloadRepositoryImpl(Get.find<IsarService>()),
      permanent: true,
    );
    Get.put<FolderRepository>(
      FolderRepositoryImpl(Get.find<IsarService>()),
      permanent: true,
    );

    // Resolvers
    Get.put<ResolverRegistry>(ResolverRegistry(), permanent: true);

    // Download manager (depends on repository + settings for concurrency)
    final downloadManager = DownloadManager(
      Get.find<DownloadRepository>(),
      settingsService: Get.find<SettingsService>(),
    );
    Get.put<DownloadManager>(downloadManager, permanent: true);
    // Requeue anything left `queued`/`downloading` from a previous session
    // (app killed mid-download) so it resumes instead of sitting stuck.
    downloadManager.resumeInterrupted();
  }
}
