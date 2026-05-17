import 'package:flutter/material.dart';

/// Typography scale for UniStream. Mirror of `DS.Typography` in
/// `tvos/UniStreamTV/UniStreamTV/Views/Components/DesignSystem.swift`.
///
/// We don't bundle a custom font — Apple platforms render SF Pro
/// natively (the `null` fontFamily resolves to the system UI font),
/// Linux falls back to DejaVu Sans / Noto Sans, Windows to Segoe UI.
/// The fallback chain below nudges everything towards a neutral
/// humanist sans so weight + tracking land close enough to SF Pro for
/// the design language to read consistently across platforms. If we
/// ever want pixel parity with tvOS on Linux/Windows we can bundle
/// Inter — see `DESIGN.md`.
///
/// Usage:
///   Text('À LA UNE', style: DSText.label)
///   Text(title, style: DSText.title1.copyWith(color: Colors.white))
class DSText {
  DSText._();

  /// Fallback chain shared by every token. Order matters: Apple system
  /// font first (resolves to SF Pro on iOS/macOS), then a humanist
  /// neutral set for non-Apple platforms.
  static const List<String> _fallback = <String>[
    '.AppleSystemUIFont',
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
  ];

  static const TextStyle _base = TextStyle(
    fontFamilyFallback: _fallback,
    height: 1.15,
  );

  /// Hero title — used for "À LA UNE" banner and detail-view headlines.
  static final TextStyle displayHero = _base.copyWith(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.5,
  );

  /// Standard display title — large headers (rare).
  static final TextStyle display = _base.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.3,
  );

  /// Section / page titles.
  static final TextStyle title1 = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.12,
  );

  /// Sub-section titles ("Continuer à regarder", "Catégories").
  static final TextStyle title2 = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.18,
  );

  /// Card titles, dialog titles.
  static final TextStyle title3 = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Body copy.
  static final TextStyle body = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Slightly emphasised body — CTAs, focus titles.
  static final TextStyle bodyEmphasised = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Metadata, year + genre + duration pills.
  static final TextStyle caption = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Labels (badges, "À LA UNE", "FILM", "VU"). Small caps emulated via
  /// uppercase + extra letter-spacing — Flutter has no built-in
  /// smallCaps fontFeature on every platform, but this combination
  /// reads identically to the SF Pro `.smallCaps()` modifier.
  static final TextStyle label = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.2,
  );
}
