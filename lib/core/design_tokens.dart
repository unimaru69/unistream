import 'package:flutter/material.dart';

import 'colors.dart';

/// Design tokens for UniStream — spacing, padding, radii, focus, motion.
/// Mirror of `DS` in `tvos/UniStreamTV/UniStreamTV/Views/Components/
/// DesignSystem.swift`. The two surfaces should stay in lock-step; see
/// `DESIGN.md` at the repo root.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(DS.space.md), …)
///   BorderRadius.circular(DS.radius.card)
///   AnimatedContainer(duration: DS.motion.standard, curve: DS.motion.curve)
///
/// Colour tokens live on `AppColors` (`lib/core/colors.dart`); typography
/// on `DSText` (`lib/core/typography.dart`); glass / blur helpers on
/// `lib/core/glass.dart`.
class DS {
  DS._();

  static const space = _Spacing();
  static const padding = _Padding();
  static const radius = _Radius();
  static const focus = _Focus();
  static const motion = _Motion();
  static const colour = _Colour();
}

/// 4-pt grid. Mirrors `DS.Spacing` (Swift).
class _Spacing {
  const _Spacing();
  final double xxs = 4;
  final double xs = 8;
  final double sm = 12;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
  final double xxl = 48;
  final double xxxl = 64;
  final double huge = 96;
}

/// Screen-edge / section paddings.
///
/// Values are intentionally tighter than the tvOS counterpart (Swift uses
/// 60pt screen / 40pt detail / 60pt bottom — the 10-foot UI breathes more).
/// Desktop / tablet UniStream uses denser figures because the user sits
/// close to the screen and a 60-pt margin would feel wasteful.
class _Padding {
  const _Padding();

  /// Horizontal padding for full-width screens.
  final double screenHorizontal = 24;

  /// Horizontal padding inside split-view detail panes.
  final double detailHorizontal = 20;

  /// Top padding below the app bar / nav title.
  final double contentTop = 16;

  /// Bottom padding at the end of a scrollable screen.
  final double contentBottom = 32;

  /// Vertical breathing room between major sections (hero → row,
  /// row → row). Matches Swift's `DS.Padding.sectionGap`.
  final double sectionGap = 48;
}

/// Corner radii. Mirrors `DS.Radius` (Swift).
class _Radius {
  const _Radius();

  /// Standard card (poster thumbnails, row backgrounds).
  final double card = 12;

  /// Larger radius for hero / detail / modal surfaces.
  final double hero = 20;

  /// Pill / chip radius — prefer `StadiumBorder` when possible.
  final double pill = 99;

  /// Small radius for badges / tags / metadata pills.
  final double tag = 6;
}

/// Focus / hover treatment. Apple-style subtle scale + soft shadow + thin
/// accent ring. Used by `HoverCard` and the hero button styles.
///
/// On desktop, focus is driven by mouse hover or keyboard nav. On iOS we
/// fall back to a press-state scale only — there's no hover concept on
/// touch surfaces.
class _Focus {
  const _Focus();

  /// Card scale on focus / hover. Matches Swift's `DS.Focus.cardScale`.
  final double cardScale = 1.10;

  /// Sidebar rows / chips — subtler.
  final double chipScale = 1.04;

  /// Shadow drop on focused cards.
  final double shadowRadius = 24;
  final double shadowY = 8;
  final double shadowOpacity = 0.5;

  /// Thin accent ring drawn on focused cards. Pulled from the brand teal
  /// at low opacity so it reads as a glow rather than a hard outline.
  final double ringWidth = 2;

  /// Standard focus animation — long enough to feel intentional, short
  /// enough that grid scrolling never feels sluggish.
  final Duration animation = const Duration(milliseconds: 180);
  final Curve curve = Curves.easeOut;
}

/// Motion durations + curves. Mirrors `DS.Motion` (Swift).
///
/// Always `easeOut`. Never `easeInOut` (rebound feel), never `linear`
/// (except player scrub bars).
class _Motion {
  const _Motion();
  final Duration quick = const Duration(milliseconds: 150);
  final Duration standard = const Duration(milliseconds: 250);
  final Duration slow = const Duration(milliseconds: 400);

  /// Spring used for hero rotation / modal entry.
  final Duration spring = const Duration(milliseconds: 450);
  final Curve curve = Curves.easeOut;
  final Curve springCurve = Curves.easeOutBack;
}

/// Convenience colour aliases that mirror `DS.Colour` on Swift. The
/// authoritative palette lives on `AppColors`; this surface exists so a
/// reader of `DesignSystem.swift` can write `DS.colour.accent` and find
/// the same value here without indirecting through `AppColors`.
class _Colour {
  const _Colour();
  Color get background => AppColors.darkBackground;
  Color get surface => AppColors.darkSurface;
  Color get surfaceElevated => AppColors.darkSurfaceElevated;
  Color get accent => AppColors.primaryBlue;
  Color get accentLight => AppColors.primaryBlueLighter;
  Color get accentWarm => AppColors.accentWarm;
  Color get error => AppColors.error;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get textPrimary => Colors.white;
  Color get textSecondary => Colors.white.withValues(alpha: 0.72);
  Color get textTertiary => Colors.white.withValues(alpha: 0.50);
  Color get textDisabled => Colors.white.withValues(alpha: 0.30);
}
