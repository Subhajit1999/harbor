import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/di/initial_bindings.dart';
import 'core/router/app_pages.dart';
import 'core/router/app_routes.dart';
import 'core/services/isar_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Services that need async init are opened once, here, before the widget
  // tree exists — InitialBindings then just re-registers these same
  // instances with GetX so the rest of the app can `Get.find` them.
  final isarService = IsarService();
  await isarService.init();
  Get.put(isarService, permanent: true); 

  final settingsService = SettingsService();
  await settingsService.init();
  Get.put(settingsService, permanent: true);

  // Single shared instance: the native `harbor/share` MethodChannel only
  // keeps one Dart-side handler registered at a time, so if two different
  // ShareIntentService objects each called setMethodCallHandler (one from
  // HarborApp, one from SplashScreen), the second registration would
  // silently steal the channel from the first, breaking whichever one
  // wasn't listening anymore. Everyone must share this one instance.
  Get.put(ShareIntentService(), permanent: true);

  runApp(const HarborApp());
}

class HarborApp extends StatefulWidget {
  const HarborApp({super.key});

  @override
  State<HarborApp> createState() => _HarborAppState();
}

class _HarborAppState extends State<HarborApp> {
  final _shareIntentService = Get.find<ShareIntentService>();
  StreamSubscription? _shareSub;

  @override
  void initState() {
    super.initState();
    _wireShareExtension();
  }

  /// Listens for content handed off from the iOS Share Extension while
  /// Harbor is already running (warm start). The cold-start case — Harbor
  /// launched *by* tapping it in the Share Sheet — is handled once,
  /// sequentially, in SplashScreen instead of racing a second timer here;
  /// see that file's doc comment for why duplicating the check here
  /// caused a real bug.
  void _wireShareExtension() {
    _shareSub = _shareIntentService.onShareReceived.listen(_handleSharedText);
  }

  void _handleSharedText(String text) {
    if (text.trim().isEmpty) return;
    // Pop back to Home first (a no-op if already there) so a share that
    // arrives while the user is mid-way through a *previous* Import/
    // Analysis flow always lands on a fresh ImportController — otherwise
    // GetX would find the existing one still registered and skip its
    // `onInit`, silently ignoring the new link.
    Get.until((route) => route.settings.name == AppRoutes.home || route.isFirst);
    Get.toNamed(AppRoutes.import, arguments: text);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Harbor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialBinding: InitialBindings(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
