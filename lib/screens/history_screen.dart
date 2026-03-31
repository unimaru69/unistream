import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/logger.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import 'series_detail_screen.dart';
import 'player/player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, String>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await WatchProgress.loadHistory();
    if (mounted) setState(() { _history = h; _loading = false; });
  }

  void _play(Map<String, String> item) {
    final mode = item['mode'] ?? 'live';
    final name = item['name'] ?? 'Sans titre';
    final url  = item['url'] ?? '';
    final cover = item['cover'] ?? '';

    if (mode == 'series' && url.isEmpty) {
      final key = item['key'] ?? '';
      final seriesId = key.startsWith('series:') ? key.substring(7) : key;
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: seriesId, title: name, cover: cover,
      )));
      return;
    }

    final resumeKey = mode == 'vod' || mode == 'series'
        ? (item['key']?.replaceFirst(RegExp(r'^(vod|series):'), '') ?? '')
        : null;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url, title: name,
      resumeKey: resumeKey,
      coverUrl: cover.isNotEmpty ? cover : null,
    )));
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e, st) { AppLogger.warning(LogModule.ui, 'Failed to parse history date', error: e, stackTrace: st); return ''; }
  }

  static const _modeLabels = {'live': 'Live', 'vod': 'VOD', 'series': 'Série'};
  static const _modeColors = {'live': Colors.redAccent, 'vod': Colors.amber, 'series': Colors.tealAccent};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              label: const Text('Effacer l\'historique', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF12122A),
                  title: const Text('Effacer l\'historique ?'),
                  content: const Text('Cette action est irréversible.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true), child: const Text('Effacer')),
                  ],
                ));
                if (ok == true) {
                  await WatchProgress.clearHistory();
                  _load();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white38, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final item = _history[i];
                final cover = item['cover'] ?? '';
                final mode  = item['mode'] ?? '';
                final ts    = item['timestamp'] ?? '';
                final itemKey = item['key'] ?? '$mode:${item['name']}';
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
                    final removedItem = Map<String, String>.from(item);
                    final removedIndex = i;
                    setState(() => _history.removeAt(i));
                    WatchProgress.deleteHistoryEntry(itemKey);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Entrée supprimée'),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () {
                          WatchProgress.reInsertHistoryEntry(removedItem);
                          setState(() => _history.insert(removedIndex.clamp(0, _history.length), removedItem));
                        },
                      ),
                      duration: const Duration(seconds: 4),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: cover.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(imageUrl: cover, width: 40, height: 40, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.play_circle, color: Colors.white24)))
                          : const Icon(Icons.play_circle, color: Colors.white38),
                      title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      subtitle: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (_modeColors[mode] ?? Colors.grey).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(_modeLabels[mode] ?? mode,
                              style: TextStyle(fontSize: 10, color: _modeColors[mode] ?? Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDate(ts), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white24),
                        tooltip: 'Supprimer',
                        onPressed: () {
                          final removedItem = Map<String, String>.from(item);
                          final removedIndex = i;
                          setState(() => _history.removeAt(i));
                          WatchProgress.deleteHistoryEntry(itemKey);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Entrée supprimée'),
                            action: SnackBarAction(
                              label: 'Annuler',
                              onPressed: () {
                                WatchProgress.reInsertHistoryEntry(removedItem);
                                setState(() => _history.insert(removedIndex.clamp(0, _history.length), removedItem));
                              },
                            ),
                            duration: const Duration(seconds: 4),
                          ));
                        },
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      hoverColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
                      onTap: () => _play(item),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

