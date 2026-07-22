import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small set of reusable accent building blocks. The app is monochrome by
/// design (charcoal dark theme, white light theme, no hue except semantic
/// status colors) — these widgets exist so the *few* deliberate "hero"
/// moments (primary buttons, active progress, favorites, splash) share one
/// consistent, subtle sheen rather than each screen inventing its own.

/// Tints [child] (typically an Icon) with [gradient] via ShaderMask —
/// defaults to the monochrome accent sheen, not a colored gradient.
class GradientTint extends StatelessWidget {
  final Widget child;
  final Gradient gradient;

  const GradientTint({
    super.key,
    required this.child,
    this.gradient = AppColors.accentSheenDark,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}

/// A progress bar whose filled portion uses the monochrome accent sheen
/// instead of a flat color — used anywhere progress should feel like a
/// "hero" moment (active downloads) rather than a utilitarian bar.
class GradientProgressBar extends StatelessWidget {
  final double value; // 0.0–1.0
  final double height;
  final Color trackColor;

  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.trackColor = Colors.white12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(height: height, color: trackColor),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  height: height,
                  decoration: const BoxDecoration(gradient: AppColors.accentSheenDark),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Wraps any tappable widget with a subtle spring-y scale-down-on-press
/// interaction plus a light haptic tick — the small motion detail that
/// makes glass cards and buttons feel alive rather than static.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  const BouncyTap({super.key, required this.child, this.onTap, this.haptic = true});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown(_) => _controller.forward();
  void _onUp(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : _onDown,
      onTapUp: widget.onTap == null ? null : _onUp,
      onTapCancel: widget.onTap == null ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// A soft, blurred glow — purely decorative background texture used behind
/// hero sections (Home header, Splash) to break up flat charcoal without
/// resorting to a busy pattern or image asset. Monochrome, low-opacity —
/// meant to be felt more than seen.
class GradientBlob extends StatelessWidget {
  final double size;
  final Gradient gradient;
  final double opacity;

  const GradientBlob({
    super.key,
    this.size = 260,
    this.gradient = AppColors.accentSheenDark,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        ),
      ),
    );
  }
}
