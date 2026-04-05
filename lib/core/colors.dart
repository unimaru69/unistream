import 'package:flutter/material.dart';

/// Centralized color palette for UniStream.
/// Every hard-coded `Color(0x…)` value used across the app should live here.
class AppColors {
  AppColors._();

  // ── Dark theme ──
  static const darkBackground = Color(0xFF0E0B1E);
  static const darkSurface = Color(0xFF161230);
  static const darkSurfaceAlt = Color(0xFF0E0E20);
  static const darkText = Color(0xFF1A1A2E);
  static const darkTextShimmer = Color(0xFF23233E);

  // ── Light theme ──
  static const lightBackground = Color(0xFFF5F5F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0F0F5);
  static const lightTextPrimary = Color(0xFF1A1A2E);
  static const lightTextSecondary = Color(0xFF4A4A5A);
  static const lightTextTertiary = Color(0xFF7A7A8A);
  static const lightTextDisabled = Color(0xFFAAAAAA);
  static const lightDivider = Color(0xFFE0E0E0);
  static const lightInputFill = Color(0xFFF5F5FA);
  static const lightBorder = Color(0xFFD0D0D8);
  static const lightIcon = Color(0xFF5A5A6A);
  static const lightShimmerBase = Color(0xFFE8E8F0);
  static const lightShimmerHighlight = Color(0xFFF0F0F8);

  // ── Brand / accent ──
  static const primaryBlue = Color(0xFF1B6B8A);
  static const primaryBlueLighter = Color(0xFF2A8AB0);
  static const accentGreen = Color(0xFF2E7D32);

  // ── Brand gradient (logo: dark violet → petrol blue) ──
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E0B1E), Color(0xFF1B6B8A)],
  );
}
