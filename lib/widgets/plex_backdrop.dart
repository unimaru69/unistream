import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';

/// Plex-style blurred backdrop for detail screens.
///
/// Lays down, in order:
///   1. a solid dark base (prevents white flash before the image loads),
///   2. the poster image filled to the whole area,
///   3. a strong blur applied over the image,
///   4. a leading→trailing darkening gradient so left-side text stays legible,
///   5. a brand-accent wash from the top-left,
///   6. a bottom vignette so the page content fades into darkness.
///
/// Mirror of the Swift `PlexBackdrop` used by the tvOS app so the two platforms
/// look and feel consistent.
class PlexBackdrop extends StatelessWidget {
  final String imageUrl;
  final double blurSigma;
  final Color tint;

  const PlexBackdrop({
    super.key,
    required this.imageUrl,
    this.blurSigma = 28,
    this.tint = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Dark base.
        ColoredBox(color: AppColors.darkBackground),

        // 2 + 3) Image + blur.
        // memCacheWidth capped at 1280 — the image is blurred to
        // mush anyway, no point decoding TMDB `original` (often
        // 1920+). Cuts ~3-4× RAM on full-screen backdrop drawers.
        if (imageUrl.isNotEmpty)
          Builder(builder: (ctx) {
            final mq = MediaQuery.of(ctx);
            final memW = (mq.size.width * mq.devicePixelRatio)
                .clamp(720, 1280)
                .round();
            return ImageFiltered(
              imageFilter:
                  ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Transform.scale(
                scale: 1.15,
                child: Opacity(
                  opacity: 0.85,
                  child: CachedNetworkImage(
                    cacheManager: AppCacheManager.instance,
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: memW,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          }),

        // 4) Leading → trailing darken.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.darkBackground.withValues(alpha: 0.85),
                AppColors.darkBackground.withValues(alpha: 0.55),
                AppColors.darkBackground.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),

        // 5) Accent wash (top-left).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, -0.9),
              radius: 1.1,
              colors: [tint.withValues(alpha: 0.22), Colors.transparent],
            ),
          ),
        ),

        // 6) Bottom vignette.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.darkBackground.withValues(alpha: 0.85)],
            ),
          ),
        ),
      ],
    );
  }
}
