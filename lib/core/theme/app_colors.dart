import 'package:flutter/material.dart';

/// Monochrome design language: charcoal (not pure OLED black) as the dark
/// base, clean white as the light base. No hue anywhere except the three
/// semantic status colors (success/warning/error) — hierarchy comes from
/// tone, opacity, and glass layering rather than color.
class AppColors {
  AppColors._();

  // Base surfaces — dark
  static const Color charcoalBlack = Color(0xFF17171A); // scaffold background
  static const Color surfaceDark = Color(0xFF1E1E22); // subtle zone fill
  static const Color surfaceElevatedDark = Color(0xFF232327); // cards
  static const Color surfaceGlassDark = Color(0x26FFFFFF); // white @ ~15% — visible, not heavy

  // Base surfaces — light
  static const Color surfaceLight = Color(0xFFFFFFFF); // scaffold background
  static const Color surfaceElevatedLight = Color(0xFFF9F9FA); // cards, one tone off white
  static const Color surfaceGlassLight = Color(0x1F000000); // black @ ~12%

  // Accent — monochrome by design: white reads as the accent against the
  // charcoal dark theme, charcoal reads as the accent against the white
  // light theme. Used for primary buttons, active states, selection,
  // favorites — the same role electric blue used to play, just without
  // the hue.
  static const Color accentDark = Color(0xFFFFFFFF);
  static const Color accentLight = Color(0xFF1C1C1E);

  // `accent`/`accentMuted` resolve to the dark-theme values since the app
  // currently runs dark-first (see AppTheme); once light-theme switching is
  // wired up in Settings, screens should move to `Theme.of(context)` reads
  // instead of these static getters.
  static const Color accent = accentDark;
  static const Color accentMuted = Color(0x80FFFFFF);

  // A very subtle two-stop sheen (not a hue shift) used on primary buttons
  // and a couple of "hero" surfaces so they don't read as flat — this is
  // the monochrome replacement for what used to be a blue/violet/pink
  // gradient. Kept understated on purpose.
  static const LinearGradient accentSheenDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFD8D8DE)],
  );

  static const LinearGradient accentSheenLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2E), Color(0xFF141416)],
  );

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
