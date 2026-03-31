import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/cache_config.dart';
import '../models/episode.dart';
import '../providers/watch_progress_provider.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import 'player/player_screen.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final String seriesId;
  final String title;
  final String cover;
  const SeriesDetailScreen({super.key, required this.seriesId, required this.title, required this.cover});
  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  Map<String, List<Episode>> _episodes = {};
  List<String> _seasons = [];
  String? _selectedSeason;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final episodesMap = await XtreamApi.getSeriesEpisodesTyped(widget.seriesId);
      final seasons = episodesMap.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      setState(() {
        _episodes = episodesMap;
        _seasons  = seasons;
        _selectedSeason = seasons.isNotEmpty ? seasons.first : null;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = 'Erreur: $e'; _loading = false; });
    }
  }

  void _playEpisode(Episode ep) {
    final epId = ep.idStr;
    final url = XtreamApi.getSeriesEpisodeUrl(epId, ep.containerExtension);
    WatchProgress.saveMeta(epId, ep.displayTitle, widget.cover, url, 'series');
    WatchProgress.saveHistory('series:$epId', ep.displayTitle, widget.cover, url, 'series');

    // Trouver l'épisode suivant dans la même saison
    Map<String, dynamic>? nextEp;
    if (_selectedSeason != null) {
      final eps = _episodes[_selectedSeason!] ?? [];
      final idx = eps.indexWhere((e) => e.idStr == epId);
      if (idx >= 0 && idx < eps.length - 1) {
        final next = eps[idx + 1];
        nextEp = {
          'id': next.id,
          'title': next.displayTitle,
          'container_extension': next.containerExtension,
          'episode_num': next.episodeNum,
        };
      }
    }

    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: ep.displayTitle,
      resumeKey: epId,
      coverUrl: widget.cover,
      nextEpisode: nextEp,
      nextEpisodeCover: widget.cover,
    ))).then((_) {
      if (mounted) ref.invalidate(watchProgressProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(watchProgressProvider).valueOrNull ?? {};
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : Row(children: [
              SizedBox(width: 220, child: Column(children: [
                if (widget.cover.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: widget.cover, cacheManager: AppCacheManager.instance, height: 160, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox(height: 160)),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(alignment: Alignment.centerLeft,
                    child: Text('Saisons', style: TextStyle(
                        color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))),
                ),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _seasons.length,
                  itemBuilder: (_, i) {
                    final s   = _seasons[i];
                    final sel = _selectedSeason == s;
                    return ListTile(
                      dense: true,
                      title: Text('Saison $s', style: TextStyle(fontSize: 13,
                          color: sel ? Colors.white : Colors.white60,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      selected: sel,
                      selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () => setState(() => _selectedSeason = s),
                    );
                  },
                )),
              ])),
              const VerticalDivider(width: 1, color: Colors.white12),
              Expanded(
                child: _selectedSeason == null
                    ? Center(child: Text(AppLocalizations.of(context)!.selectionneSaison,
                        style: const TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _episodes[_selectedSeason]?.length ?? 0,
                        itemBuilder: (_, i) {
                          final ep    = _episodes[_selectedSeason]![i];
                          final epNum = ep.number != 0 ? ep.number : i + 1;
                          final title = ep.displayTitle;
                          final prog  = progress[ep.idStr];
                          final bool isWatched = prog != null && prog > 0.95;
                          final bool isPartial = prog != null && prog <= 0.95;
                          final bool isNew     = prog == null;
                          return ListTile(
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isWatched
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : AppColors.primaryBlue.withValues(alpha: 0.2),
                                  child: isWatched
                                      ? const Icon(Icons.check, size: 16, color: Colors.green)
                                      : Text('$epNum',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                ),
                                if (isNew)
                                  Positioned(top: -2, right: -2,
                                    child: Container(
                                      width: 10, height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(title, style: TextStyle(fontSize: 14,
                                color: isWatched ? Colors.white38 : Colors.white)),
                            subtitle: isPartial
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      backgroundColor: Colors.white12,
                                      color: Colors.amber, minHeight: 3,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                : isWatched
                                ? const Text('Vu', style: TextStyle(fontSize: 11, color: Colors.green))
                                : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                            onTap: () => _playEpisode(ep),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

