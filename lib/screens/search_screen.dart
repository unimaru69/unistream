import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/skeleton_list.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Key for storing search history in SharedPreferences.
const _searchHistoryKey = 'search_history';
const _maxHistory = 10;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabCtrl;
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  // Watch status filter: 0 = Tous, 1 = Non vus, 2 = En cours
  int _statusFilter = 0;

  // Search history
  List<String> _searchHistory = [];

  /// Decode base64-encoded EPG strings from Xtream API.
  static String _decodeBase64(String s) {
    if (s.isEmpty) return '';
    try { return utf8.decode(base64.decode(s)); } catch (_) { return s; }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
    _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_searchHistoryKey);
    if (raw != null && mounted) setState(() => _searchHistory = raw);
  }

  Future<void> _addToHistory(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _searchHistory.remove(q);
    _searchHistory.insert(0, q);
    if (_searchHistory.length > _maxHistory) {
      _searchHistory = _searchHistory.sublist(0, _maxHistory);
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_searchHistoryKey, _searchHistory);
  }

  Future<void> _clearHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_searchHistoryKey);
    setState(() => _searchHistory = []);
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().length < 2) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search();
      _addToHistory(v.trim());
    });
  }

  void _setQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
    _onChanged(q);
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

      // EPG program search — scan cached EPG and also load for catch-up channels
      final epgResults = await _searchEpg(q, liveChannels);

      if (mounted) {
        setState(() {
          _results = [
            ...tagLive(liveChannels),
            ...tagVod(vodItems),
            ...tagSeries(seriesItems),
            ...epgResults,
          ];
          _loading = false;
        });
      }
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Search failed', error: e, stackTrace: st);
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Search EPG program titles across live channels (full day EPG).
  Future<List<Map<String, dynamic>>> _searchEpg(String q, List<Channel> channels) async {
    final results = <Map<String, dynamic>>[];
    // Search all channels (not just catch-up) — take first 30 for performance
    final channelsToSearch = channels.take(30).toList();

    final futures = channelsToSearch.map((ch) async {
      try {
        final data = await XtreamApi.getFullDayEpg(ch.streamId.toString());
        final listings = data['epg_listings'] as List?;
        if (listings == null) return;
        for (final raw in listings) {
          final prog = raw as Map<String, dynamic>;
          final title = _decodeBase64(prog['title']?.toString() ?? '');
          if (title.isEmpty) continue;
          // Match on title first (fast check), then description if needed
          final titleMatch = title.toLowerCase().contains(q);
          if (!titleMatch) {
            final desc = _decodeBase64(prog['description']?.toString() ?? '');
            if (!desc.toLowerCase().contains(q)) continue;
          }
          final startEpoch = int.tryParse(prog['start_timestamp']?.toString() ?? '');
          final endEpoch = int.tryParse(prog['stop_timestamp']?.toString() ?? '');
          if (startEpoch == null || endEpoch == null) continue;
          final startUtc = DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000, isUtc: true);
          final endUtc = DateTime.fromMillisecondsSinceEpoch(endEpoch * 1000, isUtc: true);
          final now = DateTime.now().toUtc();
          final isPast = endUtc.isBefore(now);
          final isCurrent = startUtc.isBefore(now) && endUtc.isAfter(now);
          final desc = titleMatch ? _decodeBase64(prog['description']?.toString() ?? '') : '';
          results.add(<String, dynamic>{
            'name': title,
            'description': desc.length > 120 ? '${desc.substring(0, 120)}…' : desc,
            'channel_name': ch.name,
            'channel_icon': ch.displayIcon,
            'stream_id': ch.streamId.toString(),
            'start_utc': startUtc.toIso8601String(),
            'end_utc': endUtc.toIso8601String(),
            'start_server_local': prog['start']?.toString() ?? '',
            'duration_min': endUtc.difference(startUtc).inMinutes,
            'is_past': isPast,
            'is_current': isCurrent,
            'has_catchup': ch.hasCatchup,
            '_mode': 'epg',
          });
        }
      } catch (_) {}
    });
    await Future.wait(futures);

    // Sort: current first, then future, then past
    results.sort((a, b) {
      final aCur = a['is_current'] == true ? 0 : (a['is_past'] == true ? 2 : 1);
      final bCur = b['is_current'] == true ? 0 : (b['is_past'] == true ? 2 : 1);
      if (aCur != bCur) return aCur.compareTo(bCur);
      return (a['start_utc'] as String).compareTo(b['start_utc'] as String);
    });
    return results.take(30).toList();
  }

  List<Map<String, dynamic>> _filtered(Map<String, double> progress) {
    List<Map<String, dynamic>> list;
    switch (_tabCtrl.index) {
      case 1: list = _results.where((r) => r['_mode'] == 'live').toList(); break;
      case 2: list = _results.where((r) => r['_mode'] == 'vod').toList(); break;
      case 3: list = _results.where((r) => r['_mode'] == 'series').toList(); break;
      case 4: list = _results.where((r) => r['_mode'] == 'epg').toList(); break;
      default: list = List.from(_results);
    }
    // Apply watch status filter (only for VOD/series items)
    if (_statusFilter == 1) {
      list = list.where((r) {
        final mode = r['_mode'] as String;
        if (mode == 'live' || mode == 'epg') return true;
        final id = mode == 'series' ? r['series_id']?.toString() : r['stream_id']?.toString();
        if (id == null) return true;
        return progress[id] == null;
      }).toList();
    } else if (_statusFilter == 2) {
      list = list.where((r) {
        final mode = r['_mode'] as String;
        if (mode == 'live' || mode == 'epg') return false;
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
    final l10n = AppLocalizations.of(context)!;
    final name = item['name'] as String? ?? l10n.sansTitre;

    if (mode == 'series') {
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: item['series_id'].toString(),
        title: name, cover: item['cover'] ?? '',
        rating: item['rating']?.toString(),
        categoryName: item['category_name']?.toString(),
        plot: item['plot']?.toString() ?? item['description']?.toString(),
      )));
      return;
    }

    if (mode == 'epg') {
      // Open catch-up or live depending on timing
      final streamId = item['stream_id'] as String;
      final isPast = item['is_past'] == true;
      final hasCatchup = item['has_catchup'] == true;
      if (isPast && hasCatchup) {
        final serverLocal = item['start_server_local'] as String? ?? '';
        final durMin = item['duration_min'] as int? ?? 60;
        String url;
        if (serverLocal.isNotEmpty) {
          url = XtreamApi.getTimeshiftUrlFromLocal(streamId, serverLocal, durMin);
        } else {
          final startUtc = DateTime.parse(item['start_utc'] as String);
          url = XtreamApi.getTimeshiftUrl(streamId, startUtc, durMin);
        }
        Navigator.push(context, slideRoute(PlayerScreen(
          url: url,
          title: '$name (${l10n.replay})',
          streamId: streamId,
          isCatchup: true,
        )));
      } else {
        // Live or future — open live stream
        final url = XtreamApi.getLiveStreamUrl(streamId);
        Navigator.push(context, slideRoute(PlayerScreen(
          url: url, title: item['channel_name'] as String? ?? name,
          streamId: streamId,
        )));
      }
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
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(watchProgressProvider).valueOrNull ?? {};
    const modeIcons = {
      'live': Icons.tv, 'vod': Icons.movie,
      'series': Icons.movie_creation, 'epg': Icons.schedule,
    };
    final modeColor = {
      'live': Colors.blue, 'vod': Colors.purple,
      'series': Colors.teal, 'epg': Colors.orange,
    };

    final showStatusFilter = _tabCtrl.index != 1 && _tabCtrl.index != 4
        && _results.isNotEmpty && _query.trim().length >= 2;

    final filtered = _filtered(progress);

    // Count per tab for badges
    final counts = {
      'live': _results.where((r) => r['_mode'] == 'live').length,
      'vod': _results.where((r) => r['_mode'] == 'vod').length,
      'series': _results.where((r) => r['_mode'] == 'series').length,
      'epg': _results.where((r) => r['_mode'] == 'epg').length,
    };

    Widget body;
    if (_query.trim().length < 2) {
      // Show search history
      if (_searchHistory.isNotEmpty) {
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Icon(Icons.history, size: 16, color: tc.textDisabled),
              const SizedBox(width: 8),
              Text(l10n.rechercheRecente,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: tc.textTertiary)),
              const Spacer(),
              TextButton(
                onPressed: _clearHistory,
                child: Text(l10n.effacerRecherches,
                    style: TextStyle(fontSize: 11, color: tc.textDisabled)),
              ),
            ]),
          ),
          ...List.generate(_searchHistory.length, (i) => ListTile(
            leading: Icon(Icons.history, color: tc.textDisabled, size: 18),
            title: Text(_searchHistory[i], style: const TextStyle(fontSize: 14)),
            dense: true,
            onTap: () => _setQuery(_searchHistory[i]),
            trailing: IconButton(
              icon: Icon(Icons.north_west, color: tc.textDisabled, size: 14),
              onPressed: () => _setQuery(_searchHistory[i]),
            ),
          )),
        ]);
      } else {
        body = Center(child: Text(l10n.tapeAuMoins2,
            style: TextStyle(color: tc.textDisabled)));
      }
    } else if (_loading) {
      body = const SkeletonList();
    } else if (filtered.isEmpty) {
      body = Center(child: Text(l10n.aucunResultat,
          style: TextStyle(color: tc.textDisabled)));
    } else {
      body = Column(children: [
        // Result count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.nResultats(filtered.length),
                style: TextStyle(fontSize: 11, color: tc.textDisabled)),
          ),
        ),
        Expanded(child: RefreshIndicator(
          onRefresh: _search,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final item = filtered[i];
              final mode = item['_mode'] as String;

              if (mode == 'epg') return _buildEpgTile(item, tc, modeColor);

              final iconUrl = mode == 'series' ? item['cover'] : item['stream_icon'];
              final id = mode == 'series' ? item['series_id']?.toString() : item['stream_id']?.toString();
              final prog = (mode != 'live' && id != null) ? progress[id] : null;
              return ListTile(
                leading: iconUrl != null && iconUrl.toString().isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: mode == 'live' ? tc.logoBg : null,
                          child: CachedNetworkImage(imageUrl: iconUrl.toString(), cacheManager: AppCacheManager.instance,
                            width: 40, height: 40, fit: mode == 'live' ? BoxFit.contain : BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, __) => SizedBox(width: 40, height: 40, child: ColoredBox(color: mode == 'live' ? tc.logoBg : tc.inputFill)),
                            errorWidget: (_, __, ___) =>
                                Icon(modeIcons[mode], color: tc.borderColor, size: 24)),
                        ))
                    : Icon(modeIcons[mode], color: modeColor[mode]),
                title: Text(item['name'] ?? '',
                    style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                subtitle: prog != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(
                          value: prog,
                          backgroundColor: tc.divider,
                          color: prog > 0.95 ? Colors.green : Colors.amber,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : null,
                trailing: Icon(modeIcons[mode], color: tc.divider, size: 14),
                hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => _open(item),
              );
            },
          ),
        )),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: tc.surface, elevation: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: l10n.rechercherCatalogue,
            hintStyle: TextStyle(color: tc.textDisabled),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: tc.textDisabled),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() { _query = ''; _results = []; });
                    },
                  )
                : null,
          ),
          onChanged: _onChanged,
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primaryBlue,
          labelStyle: const TextStyle(fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.tout),
            _buildTab(l10n.live, counts['live'] ?? 0),
            _buildTab(l10n.films, counts['vod'] ?? 0),
            _buildTab(l10n.series, counts['series'] ?? 0),
            _buildTab(l10n.programmesTV, counts['epg'] ?? 0),
          ],
        ),
      ),
      body: Column(children: [
        if (showStatusFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              Icon(Icons.filter_list, size: 16, color: tc.textDisabled),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l10n.tout, style: const TextStyle(fontSize: 12)),
                selected: _statusFilter == 0,
                onSelected: (_) => setState(() => _statusFilter = 0),
                selectedColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                backgroundColor: tc.inputFill,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 0 ? tc.textPrimary : tc.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(l10n.nonVus, style: const TextStyle(fontSize: 12)),
                selected: _statusFilter == 1,
                onSelected: (_) => setState(() => _statusFilter = 1),
                selectedColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                backgroundColor: tc.inputFill,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 1 ? tc.textPrimary : tc.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(l10n.enCoursFiltre, style: const TextStyle(fontSize: 12)),
                selected: _statusFilter == 2,
                onSelected: (_) => setState(() => _statusFilter = 2),
                selectedColor: Colors.amber.withValues(alpha: 0.3),
                backgroundColor: tc.inputFill,
                side: BorderSide.none,
                labelStyle: TextStyle(color: _statusFilter == 2 ? Colors.amber : tc.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _buildTab(String label, int count) {
    if (count == 0 || _query.trim().length < 2) return Tab(text: label);
    return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count', style: const TextStyle(fontSize: 9,
            fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
      ),
    ]));
  }

  Widget _buildEpgTile(Map<String, dynamic> item, AppThemeColors tc,
      Map<String, Color> modeColor) {
    final isPast = item['is_past'] == true;
    final isCurrent = item['is_current'] == true;
    final hasCatchup = item['has_catchup'] == true;
    final channelName = item['channel_name'] as String? ?? '';
    final durMin = item['duration_min'] as int? ?? 0;

    // Format time
    final startUtc = DateTime.tryParse(item['start_utc'] ?? '');
    final timeStr = startUtc != null
        ? '${startUtc.toLocal().hour.toString().padLeft(2, '0')}:${startUtc.toLocal().minute.toString().padLeft(2, '0')}'
        : '';

    return ListTile(
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: isCurrent ? Colors.green : Colors.orange, size: 20),
          Text(timeStr, style: TextStyle(fontSize: 9, color: tc.textDisabled)),
        ],
      ),
      title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        Text(channelName, style: TextStyle(fontSize: 11, color: tc.textDisabled)),
        const SizedBox(width: 6),
        Text('${durMin}min', style: TextStyle(fontSize: 10, color: tc.textDisabled)),
        if (isCurrent) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('EN DIRECT', style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        ],
        if (isPast && hasCatchup) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.replay, size: 8, color: AppColors.accentGreen),
              SizedBox(width: 2),
              Text('REPLAY', style: TextStyle(fontSize: 8,
                  fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
            ]),
          ),
        ],
      ]),
      trailing: Icon(Icons.schedule, color: tc.divider, size: 14),
      hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => _open(item),
    );
  }
}
