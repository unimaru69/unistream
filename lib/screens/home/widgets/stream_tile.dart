import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/content_mode.dart';

/// Helper for cached network images used across the home screen widgets.
Widget networkImage(String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  ContentMode mode = ContentMode.vod,
}) {
  return CachedNetworkImage(
    imageUrl: url,
    width: width, height: height, fit: fit,
    placeholder: (_, __) => Container(color: Colors.white10),
    errorWidget: (_, __, ___) => Container(
      color: Colors.white10,
      child: Icon(mode == ContentMode.series ? Icons.movie : Icons.tv,
          color: Colors.white24, size: 24),
    ),
  );
}

/// Small icon for list view rows.
Widget listIcon(Map<String, dynamic> stream, ContentMode mode) {
  final iconUrl = mode == ContentMode.series ? stream['cover'] : stream['stream_icon'];
  final fallback = Icon(mode == ContentMode.series ? Icons.movie : Icons.tv, color: Colors.white38);
  if (iconUrl == null || iconUrl.toString().isEmpty) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: networkImage(iconUrl.toString(), width: 40, height: 40, mode: mode),
  );
}

/// Grid tile for a single stream/channel (VOD or Series grid view).
class StreamGridTile extends StatelessWidget {
  final Map<String, dynamic> stream;
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
    final cover = mode == ContentMode.series ? stream['cover'] : stream['stream_icon'];

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: selectionMode ? null : onSecondaryTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(fit: StackFit.expand, children: [
              if (cover != null && cover.toString().isNotEmpty)
                networkImage(cover.toString(), mode: mode)
              else
                Container(color: Colors.white10,
                    child: Icon(mode == ContentMode.series ? Icons.movie : Icons.tv,
                        color: Colors.white24, size: 32)),
              // Progress bar
              if (progress != null)
                Positioned(bottom: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    value: progress!,
                    backgroundColor: Colors.black45,
                    color: Colors.amber,
                    minHeight: 4,
                  ),
                ),
              // Remove from collection
              if (!selectionMode && isInCollection)
                Positioned(bottom: 4, right: 4,
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
              // Watchlist bookmark
              if (mode != ContentMode.live)
                Positioned(top: 4, left: 4,
                  child: GestureDetector(
                    onTap: onToggleWatchlist,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                          color: isInWatchlist ? Colors.tealAccent : Colors.white54, size: 14),
                    ),
                  ),
                ),
              // Favorite star
              if (!selectionMode)
                Positioned(top: 4, right: 4,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : Colors.white54, size: 14),
                    ),
                  ),
                ),
              // Selection checkbox
              if (selectionMode)
                Positioned(top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4A90D9) : Colors.black54,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(isSelected ? Icons.check : Icons.circle_outlined,
                        color: Colors.white, size: 16),
                  ),
                ),
              // Selection border
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4A90D9), width: 2),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 5),
        Text(stream['name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
