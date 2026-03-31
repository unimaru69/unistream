import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final String seriesId;
  final String title;
  final String cover;
  const SeriesDetailScreen({super.key, required this.seriesId, required this.title, required this.cover});
  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  Map<String, List<dynamic>> _episodes = {};
  List<String> _seasons = [];
  String? _selectedSeason;
  bool _loading = true;
  String? _error;
  Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadInfo();
    WatchProgress.loadAll().then((m) => setState(() => _progress = m));
  }

  Future<void> _loadInfo() async {
    try {
      final info    = await XtreamApi.getSeriesInfo(widget.seriesId);
      final raw     = info['episodes'] as Map<String, dynamic>? ?? {};
      final seasons = raw.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      setState(() {
        _episodes = raw.map((k, v) => MapEntry(k, List<dynamic>.from(v)));
        _seasons  = seasons;
        _selectedSeason = seasons.isNotEmpty ? seasons.first : null;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = 'Erreur: $e'; _loading = false; });
    }
  }

  void _playEpisode(Map<String, dynamic> ep) {
    final epId = ep['id'].toString();
    final url = XtreamApi.getSeriesEpisodeUrl(epId, ep['container_extension'] ?? 'mp4');
    WatchProgress.saveMeta(epId, ep['title'] ?? widget.title, widget.cover, url, 'series');
    WatchProgress.saveHistory('series:$epId', ep['title'] ?? widget.title, widget.cover, url, 'series');

    // Trouver l'épisode suivant dans la même saison
    Map<String, dynamic>? nextEp;
    if (_selectedSeason != null) {
      final eps = _episodes[_selectedSeason!] ?? [];
      final idx = eps.indexWhere((e) => e['id'].toString() == epId);
      if (idx >= 0 && idx < eps.length - 1) {
        nextEp = Map<String, dynamic>.from(eps[idx + 1]);
      }
    }

    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: ep['title'] ?? widget.title,
      resumeKey: ep['id'].toString(),
      coverUrl: widget.cover,
      nextEpisode: nextEp,
      nextEpisodeCover: widget.cover,
    ))).then((_) async {
      final m = await WatchProgress.loadAll();
      if (mounted) setState(() => _progress = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
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
                      child: CachedNetworkImage(imageUrl: widget.cover, height: 160, fit: BoxFit.cover,
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
                      selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () => setState(() => _selectedSeason = s),
                    );
                  },
                )),
              ])),
              const VerticalDivider(width: 1, color: Colors.white12),
              Expanded(
                child: _selectedSeason == null
                    ? const Center(child: Text('Sélectionne une saison',
                        style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _episodes[_selectedSeason]?.length ?? 0,
                        itemBuilder: (_, i) {
                          final ep    = _episodes[_selectedSeason]![i] as Map<String, dynamic>;
                          final epNum = ep['episode_num'] ?? i + 1;
                          final title = ep['title'] ?? 'Episode $epNum';
                          final prog  = _progress[ep['id']?.toString()];
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
                                      : const Color(0xFF4A90D9).withValues(alpha: 0.2),
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
                                        color: Color(0xFF4A90D9),
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
                            hoverColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
                            onTap: () => _playEpisode(ep),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

