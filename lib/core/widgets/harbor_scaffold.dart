import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'gradient_widgets.dart';

/// Full-bleed screen shell used by every screen instead of `Scaffold` +
/// `AppBar` — the neon gradient glow stretches behind the status bar (no
/// AppBar eating vertical space for a flat bar), with a custom header row
/// (auto back button + title + actions) sitting in the safe area below it.
///
/// [showBackButton] auto-detects via `Navigator.canPop`, so root screens
/// (currently only Home) get no back button for free without every call
/// site having to know its own place in the stack.
class HarborScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final Color? backgroundColor;
  final EdgeInsetsGeometry headerPadding;
  final bool glow;

  const HarborScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    required this.body,
    this.bottom,
    this.showBackButton = true,
    this.backgroundColor,
    this.headerPadding = const EdgeInsets.fromLTRB(12, 8, 16, 4),
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.charcoalBlack,
      body: Stack(
        children: [
          if (glow)
            Positioned(
              top: -110,
              right: -70,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const GradientBlob(size: 260, opacity: 0.30),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: headerPadding,
                  child: Row(
                    children: [
                      if (canPop) ...[
                        HeaderIconButton(
                          icon: CupertinoIcons.back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: titleWidget ??
                            (title != null
                                ? Text(
                                    title!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(fontSize: 30),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : const SizedBox.shrink()),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                if (bottom != null) bottom!,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one icon-button shape used in headers — a glass circle so it reads
/// consistently whether it's sitting over the gradient glow or plain
/// canvas. Used for the auto back button and any header action (search,
/// settings, etc).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const HeaderIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceGlassDark,
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, size: 19, color: AppColors.textPrimaryDark),
      ),
    );
  }
}
