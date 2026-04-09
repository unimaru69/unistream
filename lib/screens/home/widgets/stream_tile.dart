import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cache_config.dart';
import '../../../models/content_mode.dart';
import '../../../models/channel.dart';
import '../../../models/vod_item.dart';
import '../../../models/series_item.dart';



/// Helper for cached network images used across the home screen widgets.
///
/// For live channel logos ([mode] == [ContentMode.live]) a dark background is
/// used regardless of theme, because IPTV logos are typically white/transparent.
Widget networkImage(String url, {
  required BuildContext context,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  ContentMode mode = ContentMode.vod,
}) {
  final tc = AppThemeColors.of(context);
  final isLogo = mode == ContentMode.live;
  final bgColor = isLogo ? tc.logoBg : tc.inputFill;
  final placeholderFit = isLogo ? BoxFit.contain : fit;
  return CachedNetworkImage(
    imageUrl: url,
    cacheManager: AppCacheManager.instance,
    width: width, height: height, fit: placeholderFit,
    fadeInDuration: const Duration(milliseconds: 200),
    placeholder: (_, __) => SizedBox(
      width: width, height: height,
      child: ColoredBox(color: bgColor),
    ),
    errorWidget: (_, __, ___) => SizedBox(
      width: width, height: height,
      child: ColoredBox(
        color: bgColor,
        child: Icon(Icons.tv, color: tc.borderColor, size: 24),
      ),
    ),
  );
}

/// Small icon for list view rows (legacy Map version).
Widget listIcon(Map<String, dynamic> stream, ContentMode mode, BuildContext context) {
  final tc = AppThemeColors.of(context);
  final iconUrl = mode == ContentMode.series ? stream['cover'] : stream['stream_icon'];
  final fallback = Icon(mode == ContentMode.series ? Icons.movie : Icons.tv, color: tc.textDisabled);
  if (iconUrl == null || iconUrl.toString().isEmpty) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Container(
      color: mode == ContentMode.live ? tc.logoBg : null,
      child: networkImage(iconUrl.toString(), context: context, width: 40, height: 40, mode: mode),
    ),
  );
}

/// Small icon for list view rows (typed version).
Widget listIconTyped(dynamic stream, ContentMode mode, BuildContext context) {
  final tc = AppThemeColors.of(context);
  final String iconUrl;
  if (stream is Channel) {
    iconUrl = stream.displayIcon;
  } else if (stream is VodItem) {
    iconUrl = stream.displayIcon;
  } else if (stream is SeriesItem) {
    iconUrl = stream.displayIcon;
  } else if (stream is Map<String, dynamic>) {
    iconUrl = (mode == ContentMode.series ? stream['cover'] : stream['stream_icon'])?.toString() ?? '';
  } else {
    iconUrl = '';
  }
  final fallback = Icon(mode == ContentMode.series ? Icons.movie : Icons.tv, color: tc.textDisabled);
  if (iconUrl.isEmpty) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Container(
      color: mode == ContentMode.live ? tc.logoBg : null,
      child: networkImage(iconUrl, context: context, width: 40, height: 40, mode: mode),
    ),
  );
}

/// Whether a stream supports catch-up replay.
bool streamHasCatchup(dynamic stream) {
  if (stream is Channel) return stream.hasCatchup;
  if (stream is Map<String, dynamic>) {
    return stream['tv_archive']?.toString() == '1';
  }
  return false;
}

/// Extract display icon from a typed or map stream.
String _streamDisplayIcon(dynamic stream) {
  if (stream is Channel) return stream.displayIcon;
  if (stream is VodItem) return stream.displayIcon;
  if (stream is SeriesItem) return stream.displayIcon;
  if (stream is Map<String, dynamic>) return stream['stream_icon']?.toString() ?? stream['cover']?.toString() ?? '';
  return '';
}

/// Extract name from a typed or map stream.
String _streamName(dynamic stream) {
  if (stream is Channel) return stream.name;
  if (stream is VodItem) return stream.name;
  if (stream is SeriesItem) return stream.name;
  if (stream is Map<String, dynamic>) return stream['name']?.toString() ?? '';
  return '';
}

/// Grid tile for a single stream/channel (VOD or Series grid view).
class StreamGridTile extends StatelessWidget {
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

  const StreamGridTile({
    super.key,
    required this.stream,
    required this.mode,
    this.progress,
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
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final cover = _streamDisplayIcon(stream);
    final name = _streamName(stream);

    return Semantics(
      button: true,
      label: [
        name,
        if (isFav) 'favori',
        if (isInWatchlist) 'à regarder',
        if (progress != null) '${(progress! * 100).round()}%',
        if (selectionMode && isSelected) 'sélectionné',
      ].join(', '),
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapUp: selectionMode ? null : onSecondaryTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(fit: StackFit.expand, children: [
                if (cover.isNotEmpty)
                  Container(
                    color: mode == ContentMode.live ? tc.logoBg : null,
                    child: networkImage(cover, context: context, mode: mode),
                  )
                else
                  Container(color: mode == ContentMode.live ? tc.logoBg : tc.inputFill,
                      child: Icon(mode == ContentMode.series ? Icons.movie : Icons.tv,
                          color: tc.borderColor, size: 32)),
                // Progress bar
                if (progress != null)
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: ExcludeSemantics(child: LinearProgressIndicator(
                      value: progress!,
                      backgroundColor: tc.divider,
                      color: Colors.amber,
                      minHeight: 4,
                    )),
                  ),
                // Remove from collection
                if (!selectionMode && isInCollection)
                  Positioned(bottom: 4, right: 4,
                    child: Semantics(
                      button: true,
                      label: 'Retirer de la collection',
                      child: GestureDetector(
                        onTap: onRemoveFromCollection,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 14),
                        ),
                      ),
                    ),
                  ),
                // Catch-up badge for live channels
                if (mode == ContentMode.live && stream is Channel && (stream as Channel).hasCatchup)
                  Positioned(bottom: 4, left: 4,
                    child: ExcludeSemantics(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.replay, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text('Replay', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                  ),
                // Watchlist bookmark
                if (mode != ContentMode.live)
                  Positioned(top: 4, left: 4,
                    child: Semantics(
                      button: true,
                      label: isInWatchlist ? 'Retirer de la liste' : 'Ajouter à regarder plus tard',
                      child: GestureDetector(
                        onTap: onToggleWatchlist,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                              color: isInWatchlist ? Colors.tealAccent : tc.textTertiary, size: 14),
                        ),
                      ),
                    ),
                  ),
                // Favorite star
                if (!selectionMode)
                  Positioned(top: 4, right: 4,
                    child: Semantics(
                      button: true,
                      label: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(isFav ? Icons.star : Icons.star_border,
                              color: isFav ? Colors.amber : tc.textTertiary, size: 14),
                        ),
                      ),
                    ),
                  ),
                // Selection checkbox
                if (selectionMode)
                  Positioned(top: 4, right: 4,
                    child: ExcludeSemantics(child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue : Colors.black54,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(isSelected ? Icons.check : Icons.circle_outlined,
                          color: tc.textPrimary, size: 16),
                    )),
                  ),
                // Selection border
                if (isSelected)
                  Positioned.fill(
                    child: ExcludeSemantics(child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryBlue, width: 2),
                      ),
                    )),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 5),
          ExcludeSemantics(child: Text(name, style: TextStyle(fontSize: 11, color: tc.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
