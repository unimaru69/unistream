import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/skeleton_list.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../repositories/preferences_repository.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/logger.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../models/search_result.dart';
import '../providers/watch_progress_provider.dart';
import '../repositories/content_repository.dart';
import '../utils/content_key.dart';
import '../utils/routes.dart';
import 'series_detail_screen.dart';
import 'player/player_screen.dart';

/// Key for storing search history in SharedPreferences.
const _maxHistory = 10;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  PreferencesRepository get _prefs => ref.read(preferencesRepositoryProvider);
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  final _ctrl = TextEditingController();
  late final TabController _tabCtrl;
  String _query = '';
  List<SearchResult> _results = [];
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
    final raw = await _prefs.getSearchHistory();
    if (raw.isNotEmpty && mounted) setState(() => _searchHistory = raw);
  }

  Future<void> _addToHistory(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _searchHistory.remove(q);
    _searchHistory.insert(0, q);
    if (_searchHistory.length > _maxHistory) {
      _searchHistory = _searchHistory.sublist(0, _maxHistory);
    }
    await _prefs.setSearchHistory(_searchHistory);
  }

  Future<void> _clearHistory() async {
    await _prefs.clearSearchHistory();
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
        _repo.getLiveStreams(),
        _repo.getVodStreams(),
        _repo.getSeries(),
      ]);
      final liveChannels = results[0] as List<Channel>;
      final vodItems = results[1] as List<VodItem>;
      final seriesItems = results[2] as List<SeriesItem>;

      final liveResults = liveChannels
          .where((ch) => ch.name.toLowerCase().contains(q))
          .take(30)
          .map((ch) => LiveSearchResult(
                name: ch.name,
                streamId: ch.streamId,
                streamIcon: ch.displayIcon,
              ))
          .toList();

      final vodResults = vodItems
          .where((v) => v.name.toLowerCase().contains(q))
          .take(30)
          .map((v) => VodSearchResult(
                name: v.name,
                streamId: v.streamId,
                streamIcon: v.displayIcon,
                containerExtension: v.containerExtension,
              ))
          .toList();

      final seriesResults = seriesItems
          .where((s) => s.name.toLowerCase().contains(q))
          .take(30)
          .map((s) => SeriesSearchResult(
                name: s.name,
                seriesId: s.seriesId,
                cover: s.displayIcon,
                rating: s.rating?.toString(),
                categoryName: s.categoryName,
                plot: s.plot ?? s.description,
              ))
          .toList();

      // EPG program search
      final epgResults = await _searchEpg(q, liveChannels);

      if (mounted) {
        setState(() {
          _results = [
            ...liveResults,
            ...vodResults,
            ...seriesResults,
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
  Future<List<EpgSearchResult>> _searchEpg(String q, List<Channel> channels) async {
    final results = <EpgSearchResult>[];
    final channelsToSearch = channels.take(30).toList();

    final futures = channelsToSearch.map((ch) async {
      try {
        final data = await _repo.getFullDayEpg(ch.streamId.toString());
        final listings = data['epg_listings'] as List?;
        if (listings == null) return;
        for (final raw in listings) {
          final prog = raw as Map<String, dynamic>;
          final title = _decodeBase64(prog['title']?.toString() ?? '');
          if (title.isEmpty) continue;
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
          final desc = titleMatch ? _decodeBase64(prog['description']?.toString() ?? '') : '';
          results.add(EpgSearchResult(
            name: title,
            description: desc.length > 120 ? '${desc.substring(0, 120)}\u2026' : desc,
            channelName: ch.name,
            channelIcon: ch.displayIcon,
            streamId: ch.streamId.toString(),
            startUtc: startUtc,
            endUtc: endUtc,
            startServerLocal: prog['start']?.toString() ?? '',
            durationMin: endUtc.difference(startUtc).inMinutes,
            isPast: endUtc.isBefore(now),
            isCurrent: startUtc.isBefore(now) && endUtc.isAfter(now),
            hasCatchup: ch.hasCatchup,
          ));
        }
      } catch (e) {
        AppLogger.debug('search', 'EPG search skipped for channel: $e');
      }
    });
    await Future.wait(futures);

    results.sort((a, b) {
      final aCur = a.isCurrent ? 0 : (a.isPast ? 2 : 1);
      final bCur = b.isCurrent ? 0 : (b.isPast ? 2 : 1);
      if (aCur != bCur) return aCur.compareTo(bCur);
      return a.startUtc.toIso8601String().compareTo(b.startUtc.toIso8601String());
    });
    return results.take(30).toList();
  }

  List<SearchResult> _filtered(Map<String, double> progress) {
    List<SearchResult> list;
    switch (_tabCtrl.index) {
      case 1: list = _results.whereType<LiveSearchResult>().toList(); break;
      case 2: list = _results.whereType<VodSearchResult>().toList(); break;
      case 3: list = _results.whereType<SeriesSearchResult>().toList(); break;
      case 4: list = _results.whereType<EpgSearchResult>().toList(); break;
      default: list = List.from(_results);
    }
    // Apply watch status filter (only for VOD/series items). Look up
    // progress by canonical content key (`vod_<id>` / `series_<id>`)
    // since v1.0.4+12 — the bare streamId form was the pre-migration
    // convention.
    if (_statusFilter == 1) {
      list = list.where((r) {
        if (r is LiveSearchResult || r is EpgSearchResult) return true;
        final key = switch (r) {
          VodSearchResult v => ContentKey.make(ContentKey.movie, v.streamId.toString()),
          SeriesSearchResult s => ContentKey.make(ContentKey.series, s.seriesId.toString()),
          _ => null,
        };
        if (key == null) return true;
        return progress[key] == null;
      }).toList();
    } else if (_statusFilter == 2) {
      list = list.where((r) {
        if (r is LiveSearchResult || r is EpgSearchResult) return false;
        final key = switch (r) {
          VodSearchResult v => ContentKey.make(ContentKey.movie, v.streamId.toString()),
          SeriesSearchResult s => ContentKey.make(ContentKey.series, s.seriesId.toString()),
          _ => null,
        };
        if (key == null) return false;
        final p = progress[key];
        return p != null && p > 0 && p <= 0.95;
      }).toList();
    }
    return list;
  }

  void _open(SearchResult item) {
    final l10n = AppLocalizations.of(context)!;

    switch (item) {
      case SeriesSearchResult s:
        Navigator.push(context, slideRoute(SeriesDetailScreen(
          seriesId: s.seriesId.toString(),
          title: s.name, cover: s.cover,
          rating: s.rating,
          categoryName: s.categoryName,
          plot: s.plot,
        )));

      case EpgSearchResult e:
        if (e.isPast && e.hasCatchup) {
          String url;
          if (e.startServerLocal.isNotEmpty) {
            url = _repo.getTimeshiftUrlFromLocal(e.streamId, e.startServerLocal, e.durationMin);
          } else {
            url = _repo.getTimeshiftUrl(e.streamId, e.startUtc, e.durationMin);
          }
          Navigator.push(context, slideRoute(PlayerScreen(
            url: url,
            title: '${e.name} (${l10n.replay})',
            streamId: e.streamId,
            isCatchup: true,
          )));
        } else {
          final url = _repo.getLiveStreamUrl(e.streamId);
          Navigator.push(context, slideRoute(PlayerScreen(
            url: url, title: e.channelName.isNotEmpty ? e.channelName : e.name,
            streamId: e.streamId,
          )));
        }

      case LiveSearchResult l:
        final url = _repo.getLiveStreamUrl(l.streamId.toString());
        Navigator.push(context, slideRoute(PlayerScreen(
          url: url, title: l.name,
          streamId: l.streamId.toString(),
        )));

      case VodSearchResult v:
        final url = _repo.getVodStreamUrl(v.streamId.toString(), v.containerExtension);
        final vKey = ContentKey.make(ContentKey.movie, v.streamId.toString());
        ref.read(watchProgressActionsProvider).saveMeta(vKey, v.name,
            v.streamIcon, url, 'vod');
        Navigator.push(context, slideRoute(PlayerScreen(
          url: url, title: v.name,
          resumeKey: vKey,
          coverUrl: v.streamIcon.isNotEmpty ? v.streamIcon : null,
        )));
    }
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
      'live': _results.whereType<LiveSearchResult>().length,
      'vod': _results.whereType<VodSearchResult>().length,
      'series': _results.whereType<SeriesSearchResult>().length,
      'epg': _results.whereType<EpgSearchResult>().length,
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
              tooltip: l10n.rechercherDots,
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

              if (item is EpgSearchResult) return _buildEpgTile(item, tc, modeColor);

              final iconUrl = switch (item) {
                LiveSearchResult l => l.streamIcon,
                VodSearchResult v => v.streamIcon,
                SeriesSearchResult s => s.cover,
                _ => '',
              };
              final id = switch (item) {
                LiveSearchResult l => l.streamId.toString(),
                VodSearchResult v => v.streamId.toString(),
                SeriesSearchResult s => s.seriesId.toString(),
                _ => '',
              };
              // Progress is keyed by the prefixed `ContentKey` (vod_X
              // / ep_X) in `watchProgressProvider`, not by the bare
              // id. VOD: direct key. Series: no aggregate exists
              // (progress lives on individual episodes), so we leave
              // the bar off.
              final progKey = item is VodSearchResult
                  ? ContentKey.make(ContentKey.movie, id)
                  : null;
              final prog = progKey != null ? progress[progKey] : null;
              return ListTile(
                leading: iconUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: item.mode == 'live' ? tc.logoBg : null,
                          child: CachedNetworkImage(imageUrl: iconUrl, cacheManager: AppCacheManager.instance,
                            width: 40, height: 40, fit: item.mode == 'live' ? BoxFit.contain : BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, __) => SizedBox(width: 40, height: 40, child: ColoredBox(color: item.mode == 'live' ? tc.logoBg : tc.inputFill)),
                            errorWidget: (_, __, ___) =>
                                Icon(modeIcons[item.mode], color: tc.borderColor, size: 24)),
                        ))
                    : Icon(modeIcons[item.mode], color: modeColor[item.mode]),
                title: Text(item.name,
                    style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                subtitle: prog != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ExcludeSemantics(child: LinearProgressIndicator(
                          value: prog,
                          backgroundColor: tc.divider,
                          color: prog > 0.95 ? Colors.green : Colors.amber,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        )),
                      )
                    : null,
                trailing: ExcludeSemantics(child: Icon(modeIcons[item.mode], color: tc.divider, size: 14)),
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
                    tooltip: l10n.annuler,
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

  Widget _buildEpgTile(EpgSearchResult item, AppThemeColors tc,
      Map<String, Color> modeColor) {
    // Format time
    final timeStr = '${item.startUtc.toLocal().hour.toString().padLeft(2, '0')}:${item.startUtc.toLocal().minute.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      label: [
        item.name,
        item.channelName,
        timeStr,
        '${item.durationMin} min',
        if (item.isCurrent) 'en direct',
        if (item.isPast && item.hasCatchup) 'replay disponible',
      ].join(', '),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, color: item.isCurrent ? Colors.green : Colors.orange, size: 20),
            Text(timeStr, style: TextStyle(fontSize: 9, color: tc.textDisabled)),
          ],
        ),
        title: Text(item.name, style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          Text(item.channelName, style: TextStyle(fontSize: 11, color: tc.textDisabled)),
          const SizedBox(width: 6),
          Text('${item.durationMin}min', style: TextStyle(fontSize: 10, color: tc.textDisabled)),
          if (item.isCurrent) ...[
            const SizedBox(width: 6),
            ExcludeSemantics(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('EN DIRECT', style: TextStyle(fontSize: 8,
                  fontWeight: FontWeight.bold, color: Colors.green)),
            )),
          ],
          if (item.isPast && item.hasCatchup) ...[
            const SizedBox(width: 6),
            ExcludeSemantics(child: Container(
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
            )),
          ],
        ]),
        trailing: ExcludeSemantics(child: Icon(Icons.schedule, color: tc.divider, size: 14)),
        hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => _open(item),
      ),
    );
  }
}
