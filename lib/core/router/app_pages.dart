import 'package:get/get.dart';
import '../../features/downloads/download_binding.dart';
import '../../features/downloads/download_queue_screen.dart';
import '../../features/home/home_binding.dart';
import '../../features/home/home_screen.dart';
import '../../features/import/analysis_screen.dart';
import '../../features/import/import_binding.dart';
import '../../features/import/import_screen.dart';
import '../../features/library/library_binding.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_binding.dart';
import '../../features/player/player_screen.dart';
import '../../features/search/search_binding.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_binding.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'app_routes.dart';

/// GetX's routing table — the third role GetX plays (alongside state and
/// DI), consciously chosen over adding GoRouter as a fourth dependency.
/// Each page's `binding` scopes its controller to just that route (except
/// Import/Analysis, which intentionally share [ImportBinding] since they're
/// one continuous flow — see that file's doc comment).
class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.home, page: () => const HomeScreen(), binding: HomeBinding()),
    GetPage(
      name: AppRoutes.import,
      page: () => const ImportScreen(),
      binding: ImportBinding(),
    ),
    GetPage(
      name: AppRoutes.analysis,
      page: () => const AnalysisScreen(),
      binding: ImportBinding(),
    ),
    GetPage(
      name: AppRoutes.downloadQueue,
      page: () => const DownloadQueueScreen(),
      binding: DownloadBinding(),
    ),
    GetPage(
      name: AppRoutes.library,
      page: () => const LibraryScreen(),
      binding: LibraryBinding(),
    ),
    GetPage(
      name: AppRoutes.player,
      page: () => const PlayerScreen(),
      binding: PlayerBinding(),
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchScreen(),
      binding: SearchBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
      binding: SettingsBinding(),
    ),
  ];
}
