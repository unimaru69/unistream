import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/skeleton_list.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../models/parsed_epg_program.dart';
import '../../providers/favorites_provider.dart';
import '../../repositories/content_repository.dart';
import '../../utils/api_error_localizer.dart';
import 'widgets/epg_day_navigator.dart';
import 'widgets/epg_timeline_header.dart';
import 'widgets/epg_program_row.dart';

// ── EPG Grid Screen ──
class EpgGridScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  const EpgGridScreen({super.key, this.initialCategoryId});
  @override
  ConsumerState<EpgGridScreen> createState() => _EpgGridScreenState();
}

class _EpgGridScreenState extends ConsumerState<EpgGridScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  // Categories
  List<cat.Category> _categories = [];
  String? _selectedCatId;
  bool _loadingCats = true;

  // Channels for selected category
  List<Channel> _channels = [];
  bool _loadingChannels = false;

  // EPG data: channelId → programs
  Map<String, List<ParsedEpgProgram>> _epgData = {};
  bool _loadingEpg = false;
  int _epgLoaded = 0; // progress counter

  String? _error;

  // Search / filter
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Category sidebar resize
  double _catSidebarWidth = 200;
  static const double _catSidebarMin = 120;
  static const double _catSidebarMax = 400;

  // Scaffold key for drawer on narrow screens
  final _epgScaffoldKey = GlobalKey<ScaffoldState>();

  // Timeline
  late DateTime _dayStart;
  final double _hourWidth = 300;
  final double _channelColWidth = 180;
  final double _rowHeight = 50;

  // Scroll sync: two independent controllers synced manually
  final _headerHScroll = ScrollController();
  final _gridHScroll   = ScrollController();
  final _channelVScroll = ScrollController();
  final _gridVScroll    = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _dayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _loadCategories();

    // Sync horizontal scroll: header ↔ grid
    _headerHScroll.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_gridHScroll.hasClients) _gridHScroll.jumpTo(_headerHScroll.offset);
      _syncingH = false;
    });
    _gridHScroll.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_headerHScroll.hasClients) _headerHScroll.jumpTo(_gridHScroll.offset);
      _syncingH = false;
    });

    // Sync vertical scroll: channel col ↔ grid
    _channelVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_gridVScroll.hasClients) _gridVScroll.jumpTo(_channelVScroll.offset);
      _syncingV = false;
    });
    _gridVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_channelVScroll.hasClients) _channelVScroll.jumpTo(_gridVScroll.offset);
      _syncingV = false;
    });
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _gridHScroll.dispose();
    _channelVScroll.dispose();
    _gridVScroll.dispose();
    super.dispose();
  }

  Future<void> _selectFavorites() async {
    setState(() {
      _selectedCatId = '__favorites__';
      _loadingChannels = true;
      _channels = [];
      _epgData = {};
      _epgLoaded = 0;
    });

    try {
      final streams = await _repo.getLiveStreams();
      final channels = streams
          .where((ch) => ref.read(favoritesProvider).keys.contains(ch.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loadingChannels = false;
        _loadingEpg = true;
      });
      await _loadEpgForChannels(channels);
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loadingChannels = false; });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getLiveCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCats = false;
      });
      // Auto-select initial category or first one
      if (cats.isNotEmpty) {
        final initId = widget.initialCategoryId;
        final match = initId != null && initId != '__favorites__' && initId != '__watchlist__'
            ? cats.firstWhere((c) => c.categoryId == initId, orElse: () => cats.first)
            : cats.first;
        _selectCategory(match.categoryId);
      }
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loadingCats = false; });
    }
  }

  Future<void> _selectCategory(String catId) async {
    setState(() {
      _selectedCatId = catId;
      _loadingChannels = true;
      _channels = [];
      _epgData = {};
      _epgLoaded = 0;
    });

    try {
      final channels = await _repo.getLiveStreams(catId);
      // Sort favorites first
      if (ref.read(favoritesProvider).keys.isNotEmpty) {
        channels.sort((a, b) {
          final aFav = ref.read(favoritesProvider).keys.contains(a.id) ? 0 : 1;
          final bFav = ref.read(favoritesProvider).keys.contains(b.id) ? 0 : 1;
          return aFav.compareTo(bFav);
        });
      }
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loadingChannels = false;
        _loadingEpg = true;
      });
      await _loadEpgForChannels(channels);
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loadingChannels = false; });
    }
  }

  List<Channel> get _filteredChannels {
    if (_searchQuery.isEmpty) return _channels;
    return _channels.where((ch) {
      // Match channel name
      if (ch.name.toLowerCase().contains(_searchQuery)) return true;
      // Also match program titles for this channel
      final progs = _epgData[ch.id] ?? [];
      return progs.any((p) => p.title.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  // ── Localized date formatting ──
  static const _frDays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _frMonths = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  static const _enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _enMonths = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

  String _fmtDay(DateTime d) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (isEn) {
      return '${_enDays[d.weekday - 1]}, ${_enMonths[d.month - 1]} ${d.day}, ${d.year}';
    }
    return '${_frDays[d.weekday - 1]} ${d.day} ${_frMonths[d.month - 1]} ${d.year}';
  }

  /// Max archive days across loaded channels (at least 3).
  int get _maxArchiveDays {
    if (_channels.isEmpty) return 3;
    final max = _channels.fold<int>(0, (prev, ch) => ch.archiveDays > prev ? ch.archiveDays : prev);
    return max.clamp(3, 14);
  }

  bool get _canGoPrev {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _dayStart.isAfter(today.subtract(Duration(days: _maxArchiveDays)));
  }

  bool get _canGoNext {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _dayStart.isBefore(today.add(const Duration(days: 3)));
  }

  void _changeDay(int delta) {
    final newDay = _dayStart.add(Duration(days: delta));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (newDay.isBefore(today.subtract(Duration(days: _maxArchiveDays))) ||
        newDay.isAfter(today.add(const Duration(days: 3)))) return;

    setState(() {
      _dayStart = newDay;
      _epgData = {};
      _epgLoaded = 0;
      _loadingEpg = true;
    });

    // Reload EPG for the new day
    if (_channels.isNotEmpty) {
      _loadEpgForChannels(_channels);
    }
  }

  /// Shared EPG loading logic — loads EPG data in batches of 6 channels,
  /// with full-day → short EPG fallback, base64 decoding, day filtering,
  /// progressive state updates, and scroll-to-current-time.
  Future<void> _loadEpgForChannels(List<Channel> channels) async {
    String dec(String s) {
      try { return utf8.decode(base64.decode(s)); }
      catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG string', error: e, stackTrace: st); return s; }
    }

    final dayEnd = _dayStart.add(const Duration(days: 1));
    final Map<String, List<ParsedEpgProgram>> epg = {};

    for (var i = 0; i < channels.length; i += 6) {
      final chunk = channels.skip(i).take(6);
      await Future.wait(chunk.map((ch) async {
        final sid = ch.id;
        try {
          Map<String, dynamic> data;
          try { data = await _repo.getFullDayEpg(sid); }
          catch (e, st) { AppLogger.warning(LogModule.epg, 'Full-day EPG failed for $sid, falling back', error: e, stackTrace: st); data = await _repo.getShortEpg(sid, limit: 30); }
          final listings = data['epg_listings'] as List? ?? [];
          epg[sid] = listings.map((e) {
            final startTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
            final stopTs  = int.tryParse((e['stop_timestamp']  ?? e['stop']  ?? '').toString());
            if (startTs == null || stopTs == null) return null;
            return ParsedEpgProgram(
              title: dec(e['title']?.toString() ?? ''),
              description: dec(e['description']?.toString() ?? ''),
              start: DateTime.fromMillisecondsSinceEpoch(startTs * 1000),
              end: DateTime.fromMillisecondsSinceEpoch(stopTs * 1000),
              startUtc: DateTime.fromMillisecondsSinceEpoch(startTs * 1000, isUtc: true),
              startServerLocal: e['start']?.toString() ?? '',
            );
          }).where((p) {
            if (p == null) return false;
            return p.start.isAfter(_dayStart.subtract(const Duration(hours: 1))) && p.start.isBefore(dayEnd);
          }).cast<ParsedEpgProgram>().toList();
        } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to load EPG for channel $sid', error: e, stackTrace: st); }
      }));
      if (mounted) {
        setState(() {
          _epgData = Map.from(epg);
          _epgLoaded = (i + 6).clamp(0, channels.length);
        });
      }
    }

    if (mounted) setState(() => _loadingEpg = false);

    // Scroll to current time (or beginning of day for past/future days)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final isToday = _dayStart.year == today.year && _dayStart.month == today.month && _dayStart.day == today.day;
      final offset = isToday
          ? DateTime.now().difference(_dayStart).inMinutes * _hourWidth / 60 - 200
          : 0.0;
      if (_gridHScroll.hasClients) {
        _gridHScroll.jumpTo(offset.clamp(0.0, _gridHScroll.position.maxScrollExtent));
      }
    });
  }

  Widget _buildTimelineHeader() => EpgTimelineHeader(
    dayStart: _dayStart,
    hourWidth: _hourWidth,
  );

  Widget _buildChannelRow(int i, List<Channel> channels) {
    final tc = AppThemeColors.of(context);
    final ch = channels[i];
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: i.isEven ? tc.surface : tc.surfaceAlt,
        border: Border(bottom: BorderSide(color: tc.inputFill, width: 0.5)),
      ),
      child: Row(children: [
        if (ch.displayIcon.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 28, height: 28,
              color: tc.logoBg,
              child: CachedNetworkImage(
                cacheManager: AppCacheManager.instance,
                imageUrl: ch.displayIcon,
                width: 28, height: 28, fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const SizedBox(width: 28, height: 28),
                errorWidget: (_, __, ___) => Icon(Icons.tv, size: 16, color: tc.borderColor),
              ),
            ),
          )
        else
          Icon(Icons.tv, size: 16, color: tc.borderColor),
        const SizedBox(width: 6),
        Expanded(child: Text(
          ch.name,
          style: TextStyle(fontSize: 11, color: tc.textSecondary),
          overflow: TextOverflow.ellipsis,
        )),
        if (ch.hasCatchup)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3)),
            child: Text('${ch.archiveDays}j',
                style: TextStyle(fontSize: 9, color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _buildProgramRow(int i, List<Channel> channels) {
    final ch = channels[i];
    return EpgProgramRow(
      channel: ch,
      programs: _epgData[ch.id] ?? [],
      dayStart: _dayStart,
      hourWidth: _hourWidth,
      rowHeight: _rowHeight,
      rowIndex: i,
      searchQuery: _searchQuery,
      repo: _repo,
    );
  }

  Widget _buildCategorySidebar(AppThemeColors tc, {bool inDrawer = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _categories.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          final sel = _selectedCatId == '__favorites__';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.star, size: 14,
                  color: sel ? Colors.amber : Colors.amber.withValues(alpha: 0.5)),
              title: Text(AppLocalizations.of(context)!.favoris, style: TextStyle(fontSize: 12,
                  color: sel ? tc.textPrimary : tc.textSecondary,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              selected: sel,
              selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () { _selectFavorites(); if (inDrawer) Navigator.pop(context); },
            ),
          );
        }
        final category = _categories[i - 1];
        final id  = category.categoryId;
        final sel = _selectedCatId == id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            dense: true,
            title: Text(category.categoryName,
                style: TextStyle(fontSize: 12,
                    color: sel ? tc.textPrimary : tc.textSecondary,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
            selected: sel,
            selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () { _selectCategory(id); if (inDrawer) Navigator.pop(context); },
          ),
        );
      },
    );
  }

  Widget _buildGridZone(AppThemeColors tc, double channelColWidth) {
    return _loadingChannels
        ? const Center(child: CircularProgressIndicator())
        : _channels.isEmpty
        ? Center(child: Text(AppLocalizations.of(context)!.selectionneCategorie,
            style: TextStyle(color: tc.textDisabled)))
        : Column(children: [
            // Day navigation bar
            EpgDayNavigator(
              dayStart: _dayStart,
              canGoPrev: _canGoPrev,
              canGoNext: _canGoNext,
              onPrev: () => _changeDay(-1),
              onNext: () => _changeDay(1),
              formatDay: _fmtDay,
              onTapDate: () {
                final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                if (_dayStart != today) {
                  setState(() => _dayStart = today);
                  _changeDay(0);
                }
              },
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.filtrerChaines,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16),
                          onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: tc.inputFill,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            // Timeline header
            Row(children: [
              Container(
                width: channelColWidth,
                height: 30,
                alignment: Alignment.center,
                color: AppColors.darkText,
                child: Text(AppLocalizations.of(context)!.nombreChaines(_filteredChannels.length),
                    style: TextStyle(fontSize: 10, color: tc.textTertiary)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHScroll,
                  scrollDirection: Axis.horizontal,
                  child: _buildTimelineHeader(),
                ),
              ),
            ]),
            // Main grid
            Expanded(
              child: Row(children: [
                // Channel names column
                SizedBox(
                  width: channelColWidth,
                  child: ListView.builder(
                    controller: _channelVScroll,
                    itemCount: _filteredChannels.length,
                    itemBuilder: (_, i) => _buildChannelRow(i, _filteredChannels),
                  ),
                ),
                // Programs grid
                Expanded(
                  child: SingleChildScrollView(
                    controller: _gridHScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _hourWidth * 24,
                      child: ListView.builder(
                        controller: _gridVScroll,
                        itemCount: _filteredChannels.length,
                        itemBuilder: (_, i) => _buildProgramRow(i, _filteredChannels),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final channelColWidth = isWide ? _channelColWidth : 120.0;

    return Scaffold(
      key: _epgScaffoldKey,
      backgroundColor: tc.surfaceAlt,
      drawer: isWide ? null : Drawer(
        child: SafeArea(child: _buildCategorySidebar(tc, inDrawer: true)),
      ),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.guideTV, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        // Force a back button as `leading`. Otherwise the Scaffold's drawer
        // makes Flutter pick the hamburger as the auto leading and the user
        // can't exit the screen. The drawer toggle lives in `actions`.
        leading: Navigator.canPop(context)
            ? const BackButton()
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _epgScaffoldKey.currentState?.openDrawer(),
            ),
          if (_loadingEpg)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(AppLocalizations.of(context)!.chargementEpg(_epgLoaded, _channels.length),
                  style: TextStyle(fontSize: 11, color: tc.textDisabled))),
            ),
          if (!_loadingEpg && _channels.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: AppLocalizations.of(context)!.reessayer,
              onPressed: () {
                setState(() { _epgData = {}; _epgLoaded = 0; _loadingEpg = true; });
                _loadEpgForChannels(_channels);
              },
            ),
        ],
      ),
      body: _loadingCats
          ? const SkeletonList(count: 8)
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () { setState(() { _error = null; _loadingCats = true; }); _loadCategories(); },
                  child: Text(AppLocalizations.of(context)!.reessayer)),
            ]))
          : isWide
          ? Row(children: [
              // Sidebar catégories (resizable)
              SizedBox(
                width: _catSidebarWidth,
                child: _buildCategorySidebar(tc),
              ),
              // Resize handle
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(() =>
                    _catSidebarWidth = (_catSidebarWidth + d.delta.dx).clamp(_catSidebarMin, _catSidebarMax)),
                  child: Container(width: 6, color: tc.divider),
                ),
              ),
              // Grid zone
              Expanded(child: _buildGridZone(tc, channelColWidth)),
            ])
          : _buildGridZone(tc, channelColWidth),
    );
  }
}

