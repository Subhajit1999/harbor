import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'gradient_widgets.dart';

/// Primary call-to-action button — monochrome (white in dark theme, a
/// subtle sheen rather than a flat fill), rounded, with a light haptic +
/// bounce on press. Used for the main action on any screen (Analyze,
/// Download, Save, etc.) — deliberately the boldest element on most
/// screens, so it stays singular per screen rather than competing with
/// itself.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return BouncyTap(
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppColors.accentSheenDark,
          boxShadow: disabled ? null : AppColors.accentGlow(),
        ),
        child: Opacity(
          opacity: disabled && !loading ? 0.4 : 1,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CupertinoActivityIndicator(color: AppColors.onAccent),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: AppColors.onAccent),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Consistent empty-state presentation (used in Library, Search, Downloads).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withOpacity(0.08),
          ),
          child: Icon(icon, size: 34, color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimaryDark)),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryDark),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    );

    // Centers vertically when the available height is bounded (e.g. a
    // tight Expanded — Import screen's recent links section) and scrolls
    // instead of overflowing if it doesn't fit. When the height is
    // unbounded (e.g. sitting directly inside a ListView, as on Home),
    // ConstrainedBox(minHeight: constraints.maxHeight) would itself demand
    // infinite height — just center it in its own padding instead, no
    // scroll wrapper needed since there's no overflow risk there.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: content),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See All', style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}
