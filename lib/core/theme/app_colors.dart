import 'package:flutter/material.dart';

/// Dark charcoal canvas with a neon blue accent — the accent carries every
/// button, active state, selection, and "hero" surface in the app, so it
/// stays singular and deliberate rather than scattered across many hues.
class AppColors {
  AppColors._();

  // Base surfaces — dark
  static const Color charcoalBlack = Color(0xFF121216); // scaffold background
  static const Color surfaceDark = Color(0xFF1C1C21); // subtle zone fill
  static const Color surfaceElevatedDark = Color(0xFF212127); // cards
  static const Color surfaceGlassDark = Color(0x26FFFFFF); // white @ ~15% — visible, not heavy

  // Base surfaces — light
  static const Color surfaceLight = Color(0xFFFFFFFF); // scaffold background
  static const Color surfaceElevatedLight = Color(0xFFF9F9FA); // cards, one tone off white
  static const Color surfaceGlassLight = Color(0x1F000000); // black @ ~12%

  // Accent — neon blue. Used for primary buttons, active states, selection,
  // favorites, links, and icon highlights.
  static const Color accentDark = Color(0xFF2E8CFF); // neon blue
  static const Color accentBrightDark = Color(0xFF00E1FF); // cyan-blue, gradient hot stop
  static const Color accentLight = Color(0xFF0A6CFF);
  static const Color accentBrightLight = Color(0xFF00A8E8);

  // `accent`/`accentMuted` resolve to the dark-theme values since the app
  // currently runs dark-first (see AppTheme); once light-theme switching is
  // wired up in Settings, screens should move to `Theme.of(context)` reads
  // instead of these static getters.
  static const Color accent = accentDark;
  static const Color accentMuted = Color(0x802E8CFF);

  // Text that sits *on top of* a filled accent surface (primary button
  // fill, selected chip) — white reads cleanly on the neon blue at every
  // stop in the gradient below, unlike the old monochrome accent where the
  // on-accent color had to flip to charcoal.
  static const Color onAccent = Color(0xFFFFFFFF);

  // Two-stop neon sheen — deep neon blue to bright cyan-blue — used on
  // primary buttons, active progress, and the hero background glow. This
  // is the "cool gradient" the rest of the app's blurred background blobs
  // are built from.
  static const LinearGradient accentSheenDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBrightDark, accentDark],
  );

  static const LinearGradient accentSheenLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBrightLight, accentLight],
  );

  // Soft glow used behind primary buttons / accented cards so the neon
  // accent reads as lit rather than just colored-in.
  static List<BoxShadow> accentGlow({double opacity = 0.35, double blur = 24}) => [
        BoxShadow(color: accentDark.withOpacity(opacity), blurRadius: blur, spreadRadius: 0),
      ];

  // Semantic
  static const Color success = Color(0xFF32D74B);
  static const Color warning = Color(0xFFFFD60A);
  static const Color error = Color(0xFFFF453A);

  // Text
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9A9AA1);
  static const Color textPrimaryLight = Color(0xFF0B0B0D);
  static const Color textSecondaryLight = Color(0xFF6B6B70);
}
