import 'package:flutter/material.dart';

/// Centralized color palette + design tokens for UniStream — version 2,
/// aligned with `tvos/UniStreamTV/UniStreamTV/Views/Components/
/// DesignSystem.swift` (Apple TV+ / Strimr-style dark UI).
///
/// Hard-coded `Color(0x…)` literals in widgets are a smell — lift them
/// here. See `DESIGN.md` at the repo root for the rationale.
class AppColors {
  AppColors._();

  // ── Dark theme (true black canvas) ───────────────────────────────
  // True black background to match Apple TV+ / Strimr first-party apps.
  // The previous 0x0E0B1E navy read more like "Plex" — too soft for the
  // cinematic feel we want.
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF141414);
  static const darkSurfaceAlt = Color(0xFF1C1C1E);
  static const darkSurfaceElevated = Color(0xFF1C1C1E);

  // Legacy aliases — still referenced by older widgets, point them at
  // the new palette so nothing visually regresses.
  static const darkText = Color(0xFF1A1A2E);
  static const darkTextShimmer = Color(0xFF23233E);

  // ── Light theme ───────────────────────────────────────────────────
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

  // ── Brand / accent ────────────────────────────────────────────────
  /// Primary brand teal. Mirrors `DS.Colour.accent` on tvOS.
  static const primaryBlue = Color(0xFF1B6B8A);
  static const primaryBlueLighter = Color(0xFF2A8AB0);
  /// Warm secondary used sparingly for "live now" / "new" highlights.
  static const accentWarm = Color(0xFFFF6B5B);
  static const accentGreen = Color(0xFF2E7D32);

  /// Status colours — match the SF Symbols system tinted accent set.
  static const error = Color(0xFFFF453A);
  static const success = Color(0xFF32D74B);
  static const warning = Color(0xFFFFD60A);

  // ── Brand gradient (logo: deep black → teal) ──────────────────────
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1B6B8A)],
  );
}

/// Spacing scale — 4-pt grid. Mirrors `DS.Spacing` on tvOS.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double huge = 96;
}

/// Corner radii — mirrors `DS.Radius` on tvOS.
class AppRadius {
  AppRadius._();
  static const double card = 12;
  static const double hero = 20;
  static const double pill = 99;
  static const double tag = 6;
}

/// Motion durations — mirrors `DS.Motion` on tvOS.
class AppMotion {
  AppMotion._();
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
