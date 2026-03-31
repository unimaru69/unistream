import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/logger.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import 'series_detail_screen.dart';
import 'player/player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabCtrl;
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  // Watch status filter: 0 = Tous, 1 = Non vus, 2 = En cours
  int _statusFilter = 0;
  Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await WatchProgress.loadAll();
    if (mounted) setState(() => _progress = p);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().length < 2) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final all = await Future.wait([
        XtreamApi.getLiveStreams(),
        XtreamApi.getVodStreams(),
        XtreamApi.getSeries(),
      ]);
      List<Map<String, dynamic>> tag(List<dynamic> list, String mode) => list
          .cast<Map<String, dynamic>>()
          .where((s) => (s['name'] ?? '').toString().toLowerCase().contains(q))
          .map((s) => {...s, '_mode': mode})
          .take(30)
          .toList();
      if (mounted) setState(() {
        _results = [...tag(all[0], 'live'), ...tag(all[1], 'vod'), ...tag(all[2], 'series')];
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Search failed', error: e, stackTrace: st);
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list;
    switch (_tabCtrl.index) {
      case 1: list = _results.where((r) => r['_mode'] == 'live').toList(); break;
      case 2: list = _results.where((r) => r['_mode'] == 'vod').toList(); break;
      case 3: list = _results.where((r) => r['_mode'] == 'series').toList(); break;
      default: list = List.from(_results);
    }
    // Apply watch status filter (only for VOD/series items)
    if (_statusFilter == 1) {
      // Non vus: no progress at all
      list = list.where((r) {
        final mode = r['_mode'] as String;
        if (mode == 'live') return true; // live always shown
        final id = mode == 'series' ? r['series_id']?.toString() : r['stream_id']?.toString();
        if (id == null) return true;
        return _progress[id] == null;
      }).toList();
    } else if (_statusFilter == 2) {
      // En cours: has progress but not finished (<=95%)
      list = list.where((r) {
        final mode = r['_mode'] as String;
        if (mode == 'live') return false; // live has no progress
        final id = mode == 'series' ? r['series_id']?.toString() : r['stream_id']?.toString();
        if (id == null) return false;
        final p = _progress[id];
        return p != null && p > 0 && p <= 0.95;
      }).toList();
    }
    return list;
  }

  void _open(Map<String, dynamic> item) {
    final mode = item['_mode'] as String;
    final name = item['name'] as String? ?? 'Sans titre';
    if (mode == 'series') {
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: item['series_id'].toString(),
        title: name, cover: item['cover'] ?? '',
      )));
      return;
    }
    final url = mode == 'live'
        ? XtreamApi.getLiveStreamUrl(item['stream_id'].toString())
        : XtreamApi.getVodStreamUrl(item['stream_id'].toString(), item['container_extension'] ?? 'mp4');
    final resumeKey = mode == 'vod' ? item['stream_id'].toString() : null;
    if (resumeKey != null) {
      WatchProgress.saveMeta(resumeKey, name,
          item['stream_icon']?.toString() ?? '', url, mode);
    }
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url, title: name,
      streamId: mode == 'live' ? item['stream_id'].toString() : null,
      resumeKey: resumeKey,
      coverUrl: mode == 'series' ? item['cover']?.toString()
          : item['stream_icon']?.toString(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    const modeIcons = {'live': Icons.tv, 'vod': Icons.movie, 'series': Icons.movie_creation};
    final modeColor = {'live': Colors.blue, 'vod': Colors.purple, 'series': Colors.teal};

    // Show status filter only when not on Live tab and results exist
    final showStatusFilter = _tabCtrl.index != 1 && _results.isNotEmpty && _query.trim().length >= 2;

    Widget body;
    if (_query.trim().length < 2) {
      body = const Center(child: Text('Tape au moins 2 caractères',
          style: TextStyle(color: Colors.white38)));
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_filtered.isEmpty) {
      body = const Center(child: Text('Aucun résultat',
          style: TextStyle(color: Colors.white38)));
    } else {
      body = ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (_, i) {
          final item = _filtered[i];
          final mode = item['_mode'] as String;
          final iconUrl = mode == 'series' ? item['cover'] : item['stream_icon'];
          // Progress indicator
          final id = mode == 'series' ? item['series_id']?.toString() : item['stream_id']?.toString();
          final prog = (mode != 'live' && id != null) ? _progress[id] : null;
          return ListTile(
            leading: iconUrl != null && iconUrl.toString().isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(imageUrl: iconUrl.toString(),
                        width: 40, height: 40, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.white10),
                        errorWidget: (_, __, ___) =>
                            Icon(modeIcons[mode], color: Colors.white24, size: 24)))
                : Icon(modeIcons[mode], color: modeColor[mode]),
            title: Text(item['name'] ?? '',
                style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            subtitle: prog != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: prog,
                      backgroundColor: Colors.white12,
                      color: prog > 0.95 ? Colors.green : Colors.amber,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
            trailing: Icon(modeIcons[mode], color: Colors.white12, size: 14),
            hoverColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => _open(item),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A), elevation: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Rechercher dans tout le catalogue…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF4A90D9),
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Live'),
            Tab(text: 'Films'),
            Tab(text: 'Séries'),
          ],
        ),
      ),
      body: Column(children: [
        if (showStatusFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              const Icon(Icons.filter_list, size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Tous', style: TextStyle(fontSize: 12)),
                selected: _statusFilter == 0,
                onSelected: (_) => setState(() => _statusFilter = 0),
                selectedColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                backgroundColor: Colors.white10,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 0 ? Colors.white : Colors.white60),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Non vus', style: TextStyle(fontSize: 12)),
                selected: _statusFilter == 1,
                onSelected: (_) => setState(() => _statusFilter = 1),
                selectedColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                backgroundColor: Colors.white10,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 1 ? Colors.white : Colors.white60),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('En cours', style: TextStyle(fontSize: 12)),
                selected: _statusFilter == 2,
                onSelected: (_) => setState(() => _statusFilter = 2),
                selectedColor: Colors.amber.withValues(alpha: 0.3),
                backgroundColor: Colors.white10,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 2 ? Colors.amber : Colors.white60),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        Expanded(child: body),
      ]),
    );
  }
}

