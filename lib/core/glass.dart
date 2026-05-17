import 'dart:ui';

import 'package:flutter/material.dart';

import 'colors.dart';

/// Apple-style glass panel — wrap a child in [GlassPanel] to get the
/// system-blur + slight tint of a light-on-dark Apple TV modal panel.
/// Mirror of `.background(.ultraThinMaterial)` on tvOS.
///
/// Reserve for **modal surfaces** (dialogs, drawer headers, EPG popovers).
/// Don't apply to large scrolling content — `BackdropFilter` is expensive,
/// and on macOS a Stack child that uses one occasionally renders blank
/// (see `feedback_mediakt_rendering.md`); test on macOS before shipping
/// any new glass usage.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.tint = const Color(0xCC141414),
    this.sigma = 30,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// Tint applied on top of the blur. Defaults to a translucent
  /// `darkSurface` — matches Apple's "ultraThin" material on a dark
  /// backdrop. Lower the alpha for a more transparent panel.
  final Color tint;

  /// Gaussian blur sigma. 30 = Apple's "ultraThin"; 50 = "regular".
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Convenience tint values matching the Swift palette.
class GlassTint {
  GlassTint._();

  /// "ultraThinMaterial" equivalent — most translucent.
  static final Color ultraThin = AppColors.darkSurface.withValues(alpha: 0.55);

  /// "regularMaterial" equivalent — denser, used for opaque-feeling
  /// modals (track picker, resume confirm).
  static final Color regular = AppColors.darkSurface.withValues(alpha: 0.78);
}
