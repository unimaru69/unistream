import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/content_mode.dart';
import '../../../models/series_item.dart';
import '../../../models/vod_item.dart';
import '../../../providers/tmdb_provider.dart';
import '../../../services/tmdb_service.dart';
import 'stream_tile.dart';

/// `StreamGridTile` wrapper that, for VOD / Series items, automatically
/// watches the TMDB cache and hands off a high-resolution poster (w500)
/// to the tile. Source posters from IPTV providers are often w185–w300
/// and pixelate hard when rendered on a 400-px-wide tile — TMDB fixes that.
///
/// Lookups are deduplicated by the provider cache, so building many tiles
/// in a single grid only costs one request per unique title.
class TmdbAwareGridTile extends ConsumerWidget {
  const TmdbAwareGridTile({
    super.key,
    required this.stream,
    required this.mode,
    required this.progress,
    required this.isFav,
    required this.isInWatchlist,
    required this.isInCollection,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleWatchlist,
    this.onRemoveFromCollection,
    required this.onSecondaryTap,
    this.subtitle,
  });

  final dynamic stream;
  final ContentMode mode;
  final double? progress;
  final bool isFav;
  final bool isInWatchlist;
  final bool isInCollection;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleWatchlist;
  final VoidCallback? onRemoveFromCollection;
  final void Function(TapUpDetails) onSecondaryTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick the TMDB lookup for VOD / Series. Live channels have no TMDB
    // counterpart.
    String? override;
    final cfg = ref.watch(tmdbConfigProvider);
    if (cfg.isActive && (mode == ContentMode.vod || mode == ContentMode.series)) {
      final title = _nameOf(stream);
      if (title.isNotEmpty) {
        final kind = mode == ContentMode.vod ? TmdbKind.movie : TmdbKind.tv;
        final lookup = ref.watch(tmdbLookupProvider(
          TmdbLookup(rawTitle: title, kind: kind),
        ));
        final tmdb = lookup.valueOrNull;
        final tmdbPoster = TmdbService.image(tmdb?.posterPath, size: 'w500');
        if (tmdbPoster != null) override = tmdbPoster;
      }
    }

    return StreamGridTile(
      stream: stream,
      mode: mode,
      progress: progress,
      isFav: isFav,
      isInWatchlist: isInWatchlist,
      isInCollection: isInCollection,
      selectionMode: selectionMode,
      isSelected: isSelected,
      onTap: onTap,
      onToggleFavorite: onToggleFavorite,
      onToggleWatchlist: onToggleWatchlist,
      onRemoveFromCollection: onRemoveFromCollection,
      onSecondaryTap: onSecondaryTap,
      subtitle: subtitle,
      posterOverride: override,
    );
  }

  String _nameOf(dynamic s) {
    if (s is VodItem) return s.name;
    if (s is SeriesItem) return s.name;
    if (s is Map<String, dynamic>) return s['name']?.toString() ?? '';
    return '';
  }
}
