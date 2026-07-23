import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
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

/// Small branded badge showing which platform a link came from — shown on
/// the Analysis screen. The only place in the app that intentionally
/// breaks from the single-accent color language: knowing "this is from
/// Instagram" at a glance is worth a recognizable color here, where
/// everywhere else stays neutral-plus-accent by design.
class SourceTag extends StatelessWidget {
  final MediaSource source;
  const SourceTag({super.key, required this.source});

  (String, Color, IconData) get _display {
    switch (source) {
      case MediaSource.youtube:
        return ('YouTube', AppColors.sourceYoutube, CupertinoIcons.play_rectangle_fill);
      case MediaSource.instagram:
        return ('Instagram', AppColors.sourceInstagram, CupertinoIcons.camera_fill);
      case MediaSource.facebook:
        return ('Facebook', AppColors.sourceFacebook, CupertinoIcons.person_2_fill);
      case MediaSource.unknown:
        return ('Unknown source', AppColors.sourceUnknown, CupertinoIcons.globe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _display;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Consistent error presentation — glass card, warning icon, message, and
/// an optional retry action. Replaces plain red `Text` error messages
/// scattered across screens with one recognizable shape.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.textPrimaryDark, height: 1.35)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text('Retry',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
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
