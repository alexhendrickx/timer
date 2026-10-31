import 'package:flutter/material.dart';

/// Central place for app-wide colors. Reference these tokens instead of
/// hardcoding hex values per screen so a single change recolors everywhere
/// (same approach as datewatch's `app_colors.dart`).
///
/// A calm, dark desktop palette: near-black background, charcoal surfaces, a
/// single restrained teal accent, broken-white text.
class AppColors {
  AppColors._();

  /// Full-window background.
  static const Color background = Color(0xFF111315);

  /// Raised surfaces: cards, dialogs, app bar, list rows.
  static const Color surface = Color(0xFF1B1E21);

  /// The one accent: running timer, primary actions, highlights.
  static const Color accent = Color(0xFF4FB8A8);

  /// Primary text and button labels.
  static const Color textPrimary = Color(0xFFF2EFEA);

  /// Secondary text: captions, inactive labels, metadata.
  static const Color textSecondary = Color(0xFF9AA0A6);

  /// Thin borders and dividers.
  static const Color hairline = Color(0xFF2A2E31);

  /// Destructive actions (delete, stop-with-discard).
  static const Color danger = Color(0xFFB3261E);
}
