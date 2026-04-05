import 'package:flutter/material.dart';
import 'colors.dart';

/// Semantic color slots that adapt to the current theme (dark / light).
///
/// Usage:
/// ```dart
/// final tc = AppThemeColors.of(context);
/// Text('Hello', style: TextStyle(color: tc.textPrimary));
/// ```
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color divider;
  final Color inputFill;
  final Color borderColor;
  final Color iconColor;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppThemeColors({
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.divider,
    required this.inputFill,
    required this.borderColor,
    required this.iconColor,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  // ── Dark variant ──
  static const dark = AppThemeColors(
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white54,
    textDisabled: Color(0x61FFFFFF), // ~Colors.white38
    divider: Color(0x1FFFFFFF), // ~Colors.white12
    inputFill: Color(0x1AFFFFFF), // ~Colors.white10
    borderColor: Color(0x3DFFFFFF), // ~Colors.white24
    iconColor: Colors.white70,
    shimmerBase: AppColors.darkText,
    shimmerHighlight: AppColors.darkTextShimmer,
  );

  // ── Light variant ──
  static const light = AppThemeColors(
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    textDisabled: AppColors.lightTextDisabled,
    divider: AppColors.lightDivider,
    inputFill: AppColors.lightInputFill,
    borderColor: AppColors.lightBorder,
    iconColor: AppColors.lightIcon,
    shimmerBase: AppColors.lightShimmerBase,
    shimmerHighlight: AppColors.lightShimmerHighlight,
  );

  /// Convenience accessor.
  static AppThemeColors of(BuildContext context) {
    return Theme.of(context).extension<AppThemeColors>() ?? dark;
  }

  @override
  AppThemeColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? divider,
    Color? inputFill,
    Color? borderColor,
    Color? iconColor,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppThemeColors(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
      borderColor: borderColor ?? this.borderColor,
      iconColor: iconColor ?? this.iconColor,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}
