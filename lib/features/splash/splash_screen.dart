import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/router/app_routes.dart';
import '../../core/services/share_intent_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_widgets.dart';

/// Minimal animated logo, per spec — a brief branded moment while the app
/// finishes anything that couldn't be done before runApp (there isn't much,
/// since Isar/SharedPreferences are opened in main() before the widget tree
/// even starts, but this gives Home's first frame a moment to settle).
///
/// This is also the ONE place that checks for a pending Share Extension
/// hand-off on cold start — deliberately not a separate timer racing this
/// screen's own auto-navigation (that used to be the bug: Splash would
/// unconditionally jump to Home ~1.1s in, even if the Import screen had
/// just been pushed on top a moment earlier for a shared link, yanking the
/// user back to Home mid-share). Checking here, sequentially, after the
/// animation finishes, means there's exactly one decision about where to
/// go next instead of two timers fighting over it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  final _shareIntentService = Get.find<ShareIntentService>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(curve);
    _glow = Tween<double>(begin: 0.15, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1100), _navigateOnward);
  }

  Future<void> _navigateOnward() async {
    if (!mounted) return;
    final pendingShare = await _shareIntentService.consumePendingShare();
    if (!mounted) return;

    Get.offAllNamed(AppRoutes.home);
    if (pendingShare != null && pendingShare.isNotEmpty) {
      Get.toNamed(AppRoutes.import, arguments: pendingShare);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                GradientBlob(size: 220, opacity: _glow.value),
                FadeTransition(
                  opacity: _fade,
                  child: Transform.scale(scale: _scale.value, child: child),
                ),
              ],
            );
          },
          child: const GradientTint(
            child: Icon(Icons.water_drop_rounded, size: 72, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
