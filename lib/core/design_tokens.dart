import 'package:flutter/material.dart';

/// Design tokens for UniStream — spacing, radii, typography, focus.
/// Mirror of the Swift `DS` enum used on tvOS so the two apps stay aligned.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(DS.space.md), …)
///   BorderRadius.circular(DS.radius.card)
class DS {
  DS._();

  // MARK: - Spacing
  static const space = _Spacing();

  // MARK: - Screen padding
  static const padding = _Padding();

  // MARK: - Corner radii
  static const radius = _Radius();

  // MARK: - Focus / interactive
  static const focus = _Focus();
}

class _Spacing {
  const _Spacing();
  final double xs = 8;
  final double sm = 12;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
  final double xxl = 40;
}

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
}

class _Radius {
  const _Radius();

  /// Standard card (poster thumbnails, row backgrounds).
  final double card = 12;

  /// Larger radius for hero / detail images.
  final double hero = 16;

  /// Pill / chip radius — prefer `StadiumBorder` when possible.
  final double pill = 99;

  /// Small radius for badges / tags.
  final double tag = 6;
}

class _Focus {
  const _Focus();

  /// Scale factor applied on focus for cards.
  final double cardScale = 1.08;

  /// Scale factor for chips / sidebar rows (subtler).
  final double chipScale = 1.04;

  /// Standard animation duration.
  final Duration animation = const Duration(milliseconds: 150);
  final Curve curve = Curves.easeOut;
}
