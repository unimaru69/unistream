import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../core/cache_config.dart';
import '../../../models/content_mode.dart';

/// Horizontal carousel of "Continue watching" items.
class ContinueWatchingRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onTap;

  const ContinueWatchingRow({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(AppLocalizations.of(context)!.continuerRegarder,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.white54, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item  = items[i];
            final ratio = item['_ratio'] as double;
            final cover = item['cover'] as String? ?? '';
            final name  = item['name']  as String? ?? '';
            return GestureDetector(
              onTap: () => onTap(item),
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(fit: StackFit.expand, children: [
                      cover.isNotEmpty
                          ? CachedNetworkImage(imageUrl: cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => const ColoredBox(color: Colors.white10),
                              errorWidget: (_, __, ___) => Container(color: Colors.white10,
                                  child: const Icon(Icons.movie, color: Colors.white24)))
                          : Container(color: Colors.white10,
                              child: const Icon(Icons.movie, color: Colors.white24)),
                      Positioned(bottom: 0, left: 0, right: 0,
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.black45,
                          color: Colors.amber,
                          minHeight: 3,
                        ),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 3),
                  Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
      const Divider(color: Colors.white12, height: 1),
    ]);
  }
}

/// Horizontal carousel of "Recently added" items.
class RecentlyAddedRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ContentMode mode;
  final void Function(Map<String, dynamic> item) onTap;

  const RecentlyAddedRow({
    super.key,
    required this.items,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || mode == ContentMode.live) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(AppLocalizations.of(context)!.recemmentAjoutes,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.white54, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item  = items[i];
            final cover = mode == ContentMode.series
                ? (item['cover'] as String? ?? '')
                : (item['stream_icon'] as String? ?? '');
            final name  = item['name'] as String? ?? '';
            return GestureDetector(
              onTap: () => onTap(item),
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: cover.isNotEmpty
                        ? CachedNetworkImage(imageUrl: cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, __) => const ColoredBox(color: Colors.white10),
                            errorWidget: (_, __, ___) => Container(color: Colors.white10,
                                child: const Icon(Icons.fiber_new, color: Colors.white24)))
                        : Container(color: Colors.white10,
                            child: const Icon(Icons.fiber_new, color: Colors.white24)),
                  )),
                  const SizedBox(height: 3),
                  Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
      const Divider(color: Colors.white12, height: 1),
    ]);
  }
}
