import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/providers/favorites_provider.dart';
import 'package:unistream/providers/watch_progress_provider.dart';

/// Displays offline-mode content: continue watching items and favorites (greyed out).
class OfflineContent extends ConsumerWidget {
  const OfflineContent({
    super.key,
    required this.onRetryConnection,
  });

  final VoidCallback onRetryConnection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineContinueItems = ref.watch(continueWatchingProvider).valueOrNull ?? [];
    final offlineFavItems = ref.watch(favoritesProvider).items;
    final l10n = AppLocalizations.of(context)!;

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.withValues(alpha: 0.15),
        child: Row(children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.modeHorsLigne,
              style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600))),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.reessayer, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: onRetryConnection,
          ),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (offlineContinueItems.isNotEmpty) ...[
            Text(l10n.continuerRegarder,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: offlineContinueItems.length,
                itemBuilder: (_, i) {
                  final item  = offlineContinueItems[i];
                  final ratio = item['_ratio'] as double;
                  final cover = item['cover'] as String? ?? '';
                  final name  = item['name']  as String? ?? '';
                  return Tooltip(
                    message: l10n.connexionRequise,
                    child: Opacity(
                      opacity: 0.5,
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
                              const Center(child: Icon(Icons.cloud_off, color: Colors.white38, size: 20)),
                            ]),
                          )),
                          const SizedBox(height: 3),
                          Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (offlineFavItems.isNotEmpty) ...[
            Text(l10n.favoris,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            ...(offlineFavItems.take(20).map((item) {
              final name = item['name'] as String? ?? '';
              final cover = item['cover']?.toString() ?? item['stream_icon']?.toString() ?? '';
              return Tooltip(
                message: l10n.connexionRequise,
                child: ListTile(
                  leading: cover.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(imageUrl: cover, cacheManager: AppCacheManager.instance, width: 40, height: 40, fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.white10)),
                              errorWidget: (_, __, ___) => const Icon(Icons.star, color: Colors.amber, size: 20)))
                      : const Icon(Icons.star, color: Colors.amber, size: 20),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.cloud_off, color: Colors.white24, size: 16),
                  dense: true,
                  enabled: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            })),
            const SizedBox(height: 24),
          ],
          if (offlineContinueItems.isEmpty && offlineFavItems.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(l10n.aucuneDonneesCache,
                    style: const TextStyle(color: Colors.white38, fontSize: 16)),
              ]),
            )),
        ]),
      )),
    ]);
  }
}
