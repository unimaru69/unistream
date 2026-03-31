import 'package:flutter/material.dart';

/// Centralized color palette for UniStream.
/// Every hard-coded `Color(0x…)` value used across the app should live here.
class AppColors {
  AppColors._();

  // ── Dark theme ──
  static const darkBackground = Color(0xFF0A0A1A);
  static const darkSurface = Color(0xFF12122A);
  static const darkSurfaceAlt = Color(0xFF0E0E20);
  static const darkText = Color(0xFF1A1A2E);
  static const darkTextShimmer = Color(0xFF23233E);

  // ── Light theme ──
  static const lightBackground = Color(0xFFF5F5F5);

  // ── Brand / accent ──
  static const primaryBlue = Color(0xFF4A90D9);
  static const accentGreen = Color(0xFF2E7D32);
}
