import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../models/continue_watching_item.dart';
import '../../../models/favorite_item.dart';
import '../../../models/series_item.dart';
import '../../../models/vod_item.dart';
import '../../../providers/tmdb_provider.dart';
import '../../../services/tmdb_service.dart';
import '../../../utils/stream_helpers.dart';
import '../../../widgets/plex_backdrop.dart';

/// Full-screen ambient backdrop. Apple-TV+-style: a sharp TMDB
/// original-size image that "fills the room" behind the page content.
/// Cross-fades smoothly when [item] changes — typically driven by the
/// hero's rotation (and optionally by the focused / hovered shelf
/// card).
///
/// Mirror of the tvOS `HomeBackdropWallpaper`
/// (`HomeTabView.swift`), which deliberately uses
/// `PlexBackdrop(blurRadius: 0)` so the page feels cinematic. Plex
/// gradients (left-darken + bottom vignette + brand wash) inside
/// [PlexBackdrop] keep the foreground content readable on top.
///
/// Pass `null` as [item] to render a flat dark canvas (cold start /
/// no rotation target available yet).
class AmbientWallpaper extends StatelessWidget {
  const AmbientWallpaper({super.key, required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const ColoredBox(color: AppColors.darkBackground);
    }
    return Consumer(builder: (context, ref, _) {
      final cfg = ref.watch(tmdbConfigProvider);
      final tmdb = cfg.isActive
          ? ref.watch(tmdbLookupProvider(TmdbLookup(
              rawTitle: getStreamName(item),
              kind: item is SeriesItem ? TmdbKind.tv : TmdbKind.movie,
            )))
          : const AsyncValue<TmdbResult?>.data(null);
      // `w780` (≈ 780×439) — backdrop is a soft full-screen ambient
      // wash, no need for `original` (1920+) and the smaller decode
      // is one of the biggest RAM wins on iPad.
      final backdropUrl =
          TmdbService.image(tmdb.valueOrNull?.backdropPath, size: 'w780') ??
              '';

      // Extension getters don't resolve on dynamic-typed references at
      // runtime — read the raw fields off the typed promoted variable
      // for a stable key.
      final keyId = item is VodItem
          ? 'vod_${item.streamId}'
          : item is SeriesItem
              ? 'series_${item.seriesId}'
              : identityHashCode(item).toString();

      return AnimatedSwitcher(
        duration: DS.motion.slow,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: PlexBackdrop(
          key: ValueKey<String>(keyId),
          imageUrl: backdropUrl,
          blurSigma: 0,
        ),
      );
    });
  }
}

/// Convert any shelf-row item into something [AmbientWallpaper] can
/// use for its TMDB lookup. Stub `VodItem` / `SeriesItem` instances
/// carry just the title — that's all the lookup needs. Returns `null`
/// for items that don't have a TMDB backdrop (live channels, catch-up
/// programs, raw provider maps), so callers can skip emitting a hover
/// target for those.
dynamic toWallpaperTarget(dynamic source) {
  if (source is VodItem || source is SeriesItem) return source;
  if (source is FavoriteItem) {
    if (source.mode == 'series') {
      return SeriesItem(seriesId: source.seriesId ?? '', name: source.name);
    }
    if (source.mode == 'vod') {
      return VodItem(streamId: source.streamId ?? '', name: source.name);
    }
    return null;
  }
  if (source is ContinueWatchingItem) {
    if (source.mode == 'series') {
      return SeriesItem(seriesId: source.id, name: source.name);
    }
    if (source.mode == 'vod') {
      return VodItem(streamId: source.id, name: source.name);
    }
    return null;
  }
  return null;
}
