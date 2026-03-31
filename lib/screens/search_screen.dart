import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/logger.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../providers/watch_progress_provider.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import 'series_detail_screen.dart';
import 'player/player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabCtrl;
  String _query = '';
  List<Map<String, dynamic>> _results = []; // tagged result maps built from typed models
  bool _loading = false;
  Timer? _debounce;

  // Watch status filter: 0 = Tous, 1 = Non vus, 2 = En cours
  int _statusFilter = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
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
      final results = await Future.wait([
        XtreamApi.getLiveStreamsTyped(),
        XtreamApi.getVodStreamsTyped(),
        XtreamApi.getSeriesTyped(),
      ]);
      final liveChannels = results[0] as List<Channel>;
      final vodItems = results[1] as List<VodItem>;
      final seriesItems = results[2] as List<SeriesItem>;

      List<Map<String, dynamic>> tagLive(List<Channel> list) => list
          .where((ch) => ch.name.toLowerCase().contains(q))
          .take(30)
          .map((ch) => <String, dynamic>{
                'stream_id': ch.streamId,
                'name': ch.name,
                'stream_icon': ch.displayIcon,
                '_mode': 'live',
              })
          .toList();

      List<Map<String, dynamic>> tagVod(List<VodItem> list) => list
          .where((v) => v.name.toLowerCase().contains(q))
          .take(30)
          .map((v) => <String, dynamic>{
                'stream_id': v.streamId,
                'name': v.name,
                'stream_icon': v.displayIcon,
                'container_extension': v.containerExtension,
                '_mode': 'vod',
              })
          .toList();

      List<Map<String, dynamic>> tagSeries(List<SeriesItem> list) => list
          .where((s) => s.name.toLowerCase().contains(q))
          .take(30)
          .map((s) => <String, dynamic>{
                'series_id': s.seriesId,
                'name': s.name,
                'cover': s.displayIcon,
                '_mode': 'series',
              })
          .toList();

      if (mounted) setState(() {
        _results = [...tagLive(liveChannels), ...tagVod(vodItems), ...tagSeries(seriesItems)];
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Search failed', error: e, stackTrace: st);
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filtered(Map<String, double> progress) {
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
        return progress[id] == null;
      }).toList();
    } else if (_statusFilter == 2) {
      // En cours: has progress but not finished (<=95%)
      list = list.where((r) {
        final mode = r['_mode'] as String;
        if (mode == 'live') return false; // live has no progress
        final id = mode == 'series' ? r['series_id']?.toString() : r['stream_id']?.toString();
        if (id == null) return false;
        final p = progress[id];
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
    final progress = ref.watch(watchProgressProvider).valueOrNull ?? {};
    const modeIcons = {'live': Icons.tv, 'vod': Icons.movie, 'series': Icons.movie_creation};
    final modeColor = {'live': Colors.blue, 'vod': Colors.purple, 'series': Colors.teal};

    // Show status filter only when not on Live tab and results exist
    final showStatusFilter = _tabCtrl.index != 1 && _results.isNotEmpty && _query.trim().length >= 2;

    final filtered = _filtered(progress);
    Widget body;
    if (_query.trim().length < 2) {
      body = Center(child: Text(AppLocalizations.of(context)!.tapeAuMoins2,
          style: const TextStyle(color: Colors.white38)));
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (filtered.isEmpty) {
      body = Center(child: Text(AppLocalizations.of(context)!.aucunResultat,
          style: const TextStyle(color: Colors.white38)));
    } else {
      body = ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final item = filtered[i];
          final mode = item['_mode'] as String;
          final iconUrl = mode == 'series' ? item['cover'] : item['stream_icon'];
          // Progress indicator
          final id = mode == 'series' ? item['series_id']?.toString() : item['stream_id']?.toString();
          final prog = (mode != 'live' && id != null) ? progress[id] : null;
          return ListTile(
            leading: iconUrl != null && iconUrl.toString().isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(imageUrl: iconUrl.toString(), cacheManager: AppCacheManager.instance,
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
            hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => _open(item),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface, elevation: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.rechercherCatalogue,
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primaryBlue,
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
                selectedColor: AppColors.primaryBlue.withValues(alpha: 0.3),
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
                selectedColor: AppColors.primaryBlue.withValues(alpha: 0.3),
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

