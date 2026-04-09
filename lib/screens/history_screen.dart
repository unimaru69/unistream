import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/models/history_entry.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import '../utils/routes.dart';
import '../utils/snackbar_helper.dart';
import 'series_detail_screen.dart';
import 'player/player_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  void _play(HistoryEntry item) {
    ScaffoldMessenger.of(context).clearSnackBars();

    if (item.mode == 'series' && item.url.isEmpty) {
      final seriesId = item.key.startsWith('series:') ? item.key.substring(7) : item.key;
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: seriesId, title: item.name, cover: item.cover,
      )));
      return;
    }

    final resumeKey = item.mode == 'vod' || item.mode == 'series'
        ? item.key.replaceFirst(RegExp(r'^(vod|series):'), '')
        : null;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: item.url, title: item.name,
      resumeKey: resumeKey,
      coverUrl: item.cover.isNotEmpty ? item.cover : null,
    )));
  }

  String _formatDate(String iso, AppLocalizations l10n) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return l10n.ilYaMinutes(diff.inMinutes);
      if (diff.inHours < 24) return l10n.ilYaHeures(diff.inHours);
      if (diff.inDays == 1) return l10n.hier;
      if (diff.inDays < 7) return l10n.ilYaJours(diff.inDays);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e, st) { AppLogger.warning(LogModule.ui, 'Failed to parse history date', error: e, stackTrace: st); return ''; }
  }

  Map<String, String> _modeLabels(AppLocalizations l10n) => {'live': l10n.live, 'vod': l10n.vod, 'series': l10n.serie};
  static const _modeColors = {'live': Colors.redAccent, 'vod': Colors.amber, 'series': Colors.tealAccent};

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final asyncHistory = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: tc.surfaceAlt,
      appBar: AppBar(
        title: Text(l10n.historique, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (asyncHistory.valueOrNull?.isNotEmpty == true)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              label: Text(l10n.effacerHistorique, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: tc.surface,
                  title: Text(l10n.effacerHistoireQuestion),
                  content: Text(l10n.actionIrreversible),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.annuler)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.effacer)),
                  ],
                ));
                if (ok == true) {
                  await ref.read(historyProvider.notifier).clearAll();
                }
              },
            ),
        ],
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.erreur}: $e', style: TextStyle(color: tc.textDisabled, fontSize: 16))),
        data: (history) {
          if (history.isEmpty) {
            return Center(child: Text(l10n.aucunHistorique, style: TextStyle(color: tc.textDisabled, fontSize: 16)));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(historyProvider.notifier).load(),
            child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (_, i) {
              final item = history[i];
              final itemKey = item.key.isNotEmpty ? item.key : '${item.mode}:${item.name}';
              return Dismissible(
                key: ValueKey(itemKey),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete, color: Colors.redAccent),
                ),
                onDismissed: (_) {
                  final removedItem = item;
                  ref.read(historyProvider.notifier).deleteEntry(itemKey);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  showAppSnackBar(context, l10n.entreeSupprimee,
                    actionLabel: l10n.annuler,
                    onAction: () => ref.read(historyProvider.notifier).reInsertEntry(removedItem),
                    duration: const Duration(seconds: 4),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: item.cover.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(imageUrl: item.cover, cacheManager: AppCacheManager.instance, width: 40, height: 40, fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => SizedBox(width: 40, height: 40, child: ColoredBox(color: tc.inputFill)),
                              errorWidget: (_, __, ___) => Icon(Icons.play_circle, color: tc.borderColor)))
                        : Icon(Icons.play_circle, color: tc.textDisabled),
                    title: Text(item.name, style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      ExcludeSemantics(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (_modeColors[item.mode] ?? Colors.grey).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(_modeLabels(l10n)[item.mode] ?? item.mode,
                            style: TextStyle(fontSize: 10, color: _modeColors[item.mode] ?? Colors.grey)),
                      )),
                      const SizedBox(width: 8),
                      Text(_formatDate(item.timestamp, l10n), style: TextStyle(fontSize: 11, color: tc.textDisabled)),
                    ]),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: tc.borderColor),
                      tooltip: l10n.supprimer,
                      onPressed: () {
                        final removedItem = item;
                        ref.read(historyProvider.notifier).deleteEntry(itemKey);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        showAppSnackBar(context, l10n.entreeSupprimee,
                          actionLabel: l10n.annuler,
                          onAction: () => ref.read(historyProvider.notifier).reInsertEntry(removedItem),
                          duration: const Duration(seconds: 4),
                        );
                      },
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                    onTap: () => _play(item),
                  ),
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }
}
