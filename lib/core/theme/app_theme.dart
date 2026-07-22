import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central theme definitions. Dark is the primary/first-class theme per the
/// product spec; light exists for System-follow but isn't the design focus.
class AppTheme {
  AppTheme._();

  static const String fontFamily = '.SF Pro Display';

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: AppColors.charcoalBlack,
        canvasColor: AppColors.charcoalBlack,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent,
          surface: AppColors.surfaceDark,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimaryDark,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceElevatedDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: EdgeInsets.zero,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: _FunkyPageTransitionsBuilder(),
            TargetPlatform.android: _FunkyPageTransitionsBuilder(),
          },
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF232327),
          thickness: 0.6,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.05,
            color: AppColors.textPrimaryDark,
          ),
          titleLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimaryDark,
          ),
          bodyLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            color: AppColors.textPrimaryDark,
          ),
          bodyMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            color: AppColors.textSecondaryDark,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          overlayColor: AppColors.accent.withOpacity(0.15),
          trackHeight: 4,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white10,
          selectedColor: AppColors.accent.withOpacity(0.25),
          labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: AppColors.surfaceLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accentLight,
          secondary: AppColors.accentLight,
          surface: AppColors.surfaceElevatedLight,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.accentLight,
          inactiveTrackColor: Colors.black12,
          thumbColor: AppColors.accentLight,
          overlayColor: AppColors.accentLight.withOpacity(0.12),
          trackHeight: 4,
        ),
      );
}

/// A gentle fade-through-with-scale transition — slightly livelier than the
/// platform default without tipping into gimmicky. Applied globally via
/// ThemeData.pageTransitionsTheme so every GetX route push gets it for free.
class _FunkyPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FunkyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
