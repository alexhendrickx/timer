import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The single app-wide theme, set once on [MaterialApp] so every screen that
/// uses plain Material widgets inherits the dark look automatically (mirrors
/// datewatch's `buildWearableTheme`). A new screen only needs the theme's
/// colors/text styles — no per-screen styling.
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    secondary: AppColors.accent,
    onSecondary: AppColors.background,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      // Disable Material 3's scroll-under surface tint so the app bar keeps a
      // flat background when content scrolls beneath it.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.accent),
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    dividerColor: AppColors.hairline,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    cardTheme: const CardThemeData(color: AppColors.surface),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
  );
}
