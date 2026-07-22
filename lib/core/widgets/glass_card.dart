import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'gradient_widgets.dart';

/// The recurring "premium glassmorphism" surface used throughout Harbor —
/// blurred, softly bordered, rounded, with a bouncy press response.
/// Centralized so every card in the app (home sections, download cards,
/// sheets) looks and feels consistent by construction.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  /// When true, renders a thin monochrome-sheen border instead of the
  /// plain hairline — reserved for the one or two "hero" cards per screen
  /// that should draw the eye (e.g. the Paste Link card on Home), not used
  /// broadly or it stops feeling special.
  final bool accented;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlassDark,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: accented ? Colors.transparent : Colors.white.withOpacity(0.14),
              width: accented ? 1.4 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (accented) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: AppColors.accentSheenDark,
        ),
        padding: const EdgeInsets.all(1.4),
        child: content,
      );
    }

    if (onTap == null) return content;
    return BouncyTap(onTap: onTap, child: content);
  }
}
