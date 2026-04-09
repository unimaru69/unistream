import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/preferences_repository.dart';
import '../../core/theme_colors.dart';
import '../../widgets/skeleton_list.dart';
import '../channel_detail_screen.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/app_config.dart';
import '../../models/collection_data.dart';
import '../../models/favorite_item.dart';
import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../models/vod_item.dart';
import '../../models/series_item.dart';
import '../../services/xtream_api.dart';
import '../../repositories/content_repository.dart';
import '../../services/watch_progress.dart';
import '../../utils/api_error_localizer.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/routes.dart';
import '../../utils/stream_helpers.dart';
import '../../models/content_mode.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/watch_progress_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/paginated_streams_provider.dart';
import '../../providers/parental_provider.dart';
import '../../services/connectivity_service.dart';
import '../settings_screen.dart';
import '../series_detail_screen.dart';
import '../player/player_screen.dart';
import '../history_screen.dart';
import '../epg/epg_grid_screen.dart';
import '../search_screen.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/stream_list.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/catchup_row.dart';
import 'widgets/collection_dialogs.dart';
import 'widgets/shortcuts_dialog.dart';
import 'widgets/offline_content.dart';
import '../vod/vod_detail_screen.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/home_keyboard_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  PreferencesRepository get _prefs => ref.read(preferencesRepositoryProvider);
  List<cat.Category> _categories = [];
  List<dynamic> _streams    = [];
  String? _selectedCategory;
  bool _loading        = true;
  bool _loadingStreams  = false;
  String? _error;
  ContentMode _mode = ContentMode.live;

  // Connectivity: track previous status for offline->online transitions
  ConnectivityStatus? _prevConnectivity;

  // Recently added (VOD/Series)
  List<dynamic> _recentlyAdded = [];

  // Catch-up programs (Live mode only)
  List<CatchupProgram> _catchupPrograms = [];

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Grid view (VOD + Series only)
  bool _gridView = false;

  // Sort mode
  String _sortMode = 'default';

  // Selection mode
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

  // Sidebar width (resizable)
  double _sidebarWidth = 250;
  static const double _sidebarMin = 150;
  static const double _sidebarMax = 400;

  // Scaffold key for drawer on narrow screens
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _init();
    _loadSidebarWidth();
    _loadGridView();
    _loadSortMode();
  }

  // ── Grid view preference per mode ──
  Future<void> _loadGridView() async {
    final v = await _prefs.getGridView(AppConfig.activeProfileId, _mode.key);
    if (v != null) setState(() => _gridView = v);
  }
  Future<void> _saveGridView() async {
    await _prefs.setGridView(AppConfig.activeProfileId, _mode.key, _gridView);
  }

  // ── Sort preference per mode ──
  Future<void> _loadSortMode() async {
    final v = await _prefs.getSortMode(AppConfig.activeProfileId, _mode.key);
    if (v != null) setState(() => _sortMode = v);
  }
  Future<void> _saveSortMode() async {
    await _prefs.setSortMode(AppConfig.activeProfileId, _mode.key, _sortMode);
  }

  // ── Collections ──
  Future<void> _createCollection() async {
    final name = await showCreateCollectionDialog(context);
    if (name != null && name.isNotEmpty) {
      await ref.read(collectionsProvider.notifier).create(name, mode: _mode.key);
    }
  }

  Future<void> _showAddToCollectionPicker(dynamic stream) async {
    final key = _favKey(_mode.key, stream);
    final name = getStreamName(stream);
    final cover = getStreamIcon(stream);
    final item = FavoriteItem(key: key, name: name.isEmpty ? AppLocalizations.of(context)!.sansTitre : name, cover: cover, mode: _mode.key);

    final collections = ref.read(collectionsProvider);
    final modeCols = collections.where((c) =>
        c.mode == null || c.mode == _mode.key).toList();
    if (modeCols.isEmpty) {
      await _createCollection();
      final updated = ref.read(collectionsProvider).where((c) =>
          c.mode == null || c.mode == _mode.key).toList();
      if (updated.isEmpty) return;
    }

    if (!mounted) return;
    final currentModeCols = ref.read(collectionsProvider).where((c) =>
        c.mode == null || c.mode == _mode.key).toList();
    final colId = await showCollectionPickerDialog(
      context,
      collections: currentModeCols,
      onCreateNew: () async {
        await _createCollection();
        if (mounted) _showAddToCollectionPicker(stream);
      },
    );
    if (colId != null) {
      await ref.read(collectionsProvider.notifier).addItem(colId, item);
      if (mounted) {
        final cols = ref.read(collectionsProvider);
        final colName = cols.firstWhere((c) => c.id == colId, orElse: () => const CollectionData(id: '', name: 'collection')).name;
        showAppSnackBar(context, AppLocalizations.of(context)!.ajouteACollection(colName));
      }
    }
  }

  String? get _activeCollectionId {
    final cat = _selectedCategory;
    if (cat != null && cat.startsWith('__col_') && cat.endsWith('__')) {
      return cat.substring(6, cat.length - 2);
    }
    return null;
  }

  Future<void> _removeFromCollection(dynamic s) async {
    final colId = _activeCollectionId;
    if (colId == null) return;
    final key = s is Map<String, dynamic>
        ? (s['key']?.toString() ?? s['_key']?.toString() ?? _favKey(_mode.key, s))
        : _favKey(_mode.key, s);
    await ref.read(collectionsProvider.notifier).removeItem(colId, key);
    final collections = ref.read(collectionsProvider);
    final col = collections.firstWhere((c) => c.id == colId, orElse: () => const CollectionData(id: '', name: ''));
    final colItems = col.items
        .where((e) => col.mode != null || e.mode == _mode.key)
        .map((e) => e.toJson())
        .toList();
    setState(() => _streams = colItems);
  }

  void _enterSelectionMode() {
    setState(() { _selectionMode = true; _selectedItems = {}; });
  }

  void _exitSelectionMode() {
    setState(() { _selectionMode = false; _selectedItems = {}; });
  }

  String _itemSelectionKey(dynamic s) {
    return _favKey(_mode.key, s);
  }

  Future<void> _createCollectionFromSelected() async {
    final items = _streams
        .where((s) => _selectedItems.contains(_itemSelectionKey(s)))
        .toList();
    if (items.isEmpty) return;

    final name = await showCreateCollectionFromSelectedDialog(context, itemCount: items.length);
    if (name == null || name.isEmpty) return;
    final col = await ref.read(collectionsProvider.notifier).create(name, mode: _mode.key);
    for (final s in items) {
      final key = _favKey(_mode.key, s);
      final itemName = getStreamName(s);
      final cover = getStreamIcon(s);
      final item = FavoriteItem(key: key, name: itemName.isEmpty ? AppLocalizations.of(context)!.sansTitre : itemName, cover: cover, mode: _mode.key);
      await ref.read(collectionsProvider.notifier).addItem(col.id, item);
    }
    _exitSelectionMode();
    if (mounted) {
      showAppSnackBar(context, AppLocalizations.of(context)!.collectionCreeAvec(name, items.length));
    }
  }

  List<dynamic> get _sortedStreams {
    if (_sortMode == 'default') return _streams;
    final list = List<dynamic>.from(_streams);
    switch (_sortMode) {
      case 'alpha':
        list.sort((a, b) => getStreamName(a).toLowerCase()
            .compareTo(getStreamName(b).toLowerCase()));
        break;
      case 'number':
        list.sort((a, b) {
          final na = int.tryParse((a is Map<String, dynamic> ? (a['num'] ?? '0') : '0').toString()) ?? 0;
          final nb = int.tryParse((b is Map<String, dynamic> ? (b['num'] ?? '0') : '0').toString()) ?? 0;
          return na.compareTo(nb);
        });
        break;
      case 'favFirst':
        list.sort((a, b) {
          final favKeys = ref.read(favoritesProvider).keys;
          final aFav = favKeys.contains(_favKey(_mode.key, a)) ? 0 : 1;
          final bFav = favKeys.contains(_favKey(_mode.key, b)) ? 0 : 1;
          if (aFav != bFav) return aFav.compareTo(bFav);
          return getStreamName(a).toLowerCase()
              .compareTo(getStreamName(b).toLowerCase());
        });
        break;
    }
    return list;
  }

  // ── Sidebar width ──
  Future<void> _loadSidebarWidth() async {
    final w = await _prefs.getSidebarWidth();
    if (w != null) setState(() => _sidebarWidth = w.clamp(_sidebarMin, _sidebarMax));
  }
  Future<void> _saveSidebarWidth() async {
    await _prefs.setSidebarWidth(_sidebarWidth);
  }

  // ── Favorites / Watchlist ──
  String _favKey(String mode, dynamic s) {
    if (s is Map<String, dynamic>) {
      final id = mode == 'series' ? s['series_id']?.toString() : s['stream_id']?.toString();
      return '$mode:$id';
    }
    final id = mode == 'series' ? getStreamId(s) : getStreamId(s);
    return '$mode:$id';
  }

  void _toggleFavorite(dynamic stream) {
    final key = _favKey(_mode.key, stream);
    final map = streamToMap(stream);
    ref.read(favoritesProvider.notifier).toggle(key, FavoriteItem.fromLegacy(key, {...map, '_mode': _mode.key}));
  }

  void _toggleWatchlist(dynamic stream) {
    final key = _favKey(_mode.key, stream);
    final map = streamToMap(stream);
    ref.read(watchlistProvider.notifier).toggle(key, FavoriteItem.fromLegacy(key, {...map, '_mode': _mode.key}));
  }

  // ── Init / loading ──
  Future<void> _init() async {
    try {
      final auth = await _repo.authenticate();
      if (auth['user_info']?['auth'] == 1) {
        _repo.loadServerTimezone();
        await _loadCategories();
      } else {
        setState(() { _error = AppLocalizations.of(context)!.authEchouee; _loading = false; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = null; });
    }
  }

  Future<void> _retryConnection() async {
    setState(() { _loading = true; _error = null; });
    ref.read(favoritesProvider.notifier).load();
    ref.read(watchlistProvider.notifier).load();
    ref.invalidate(watchProgressProvider);
    ref.invalidate(continueWatchingProvider);
    _init();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      _categories = switch (_mode) {
        ContentMode.live   => await _repo.getLiveCategories(),
        ContentMode.vod    => await _repo.getVodCategories(),
        ContentMode.series => await _repo.getSeriesCategories(),
      };
      setState(() => _loading = false);
      _loadRecentlyAdded();
      _loadCatchupPrograms();
    } catch (e) {
      setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loading = false; });
    }
  }

  Future<void> _loadRecentlyAdded() async {
    if (_mode == ContentMode.live) {
      setState(() => _recentlyAdded = []);
      return;
    }
    try {
      final List<dynamic> all = _mode == ContentMode.vod
          ? await _repo.getVodStreams()
          : await _repo.getSeries();
      final items = all.where((s) {
        final added = (s is VodItem ? s.added : s is SeriesItem ? s.added : null)?.toString() ?? '0';
        final lastMod = (s is VodItem ? s.lastModified : s is SeriesItem ? s.lastModified : null)?.toString() ?? '0';
        return (added.isNotEmpty && added != '0') || (lastMod.isNotEmpty && lastMod != '0');
      }).toList();
      items.sort((a, b) {
        final ta = int.tryParse((a is VodItem ? a.added : a is SeriesItem ? a.added : null)?.toString() ?? '0') ?? 0;
        final tb = int.tryParse((b is VodItem ? b.added : b is SeriesItem ? b.added : null)?.toString() ?? '0') ?? 0;
        final ma = int.tryParse((a is VodItem ? a.lastModified : a is SeriesItem ? a.lastModified : null)?.toString() ?? '0') ?? 0;
        final mb = int.tryParse((b is VodItem ? b.lastModified : b is SeriesItem ? b.lastModified : null)?.toString() ?? '0') ?? 0;
        final sa = ta > ma ? ta : ma;
        final sb = tb > mb ? tb : mb;
        return sb.compareTo(sa);
      });
      if (mounted) setState(() => _recentlyAdded = items.take(20).toList());
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Failed to load recently added items', error: e, stackTrace: st);
    }
  }

  /// Load recently-aired programs from catch-up enabled channels.
  Future<void> _loadCatchupPrograms() async {
    if (_mode != ContentMode.live) {
      if (_catchupPrograms.isNotEmpty) setState(() => _catchupPrograms = []);
      return;
    }
    try {
      // Get all live channels to find catch-up enabled ones
      final allChannels = await _repo.getLiveStreams();
      final catchupChannels = allChannels.where((ch) => ch.hasCatchup).take(15).toList();
      if (catchupChannels.isEmpty) return;

      final now = DateTime.now().toUtc();
      final programs = <CatchupProgram>[];

      // Load short EPG (2 recent programs) for each catch-up channel in parallel
      final futures = catchupChannels.map((ch) async {
        try {
          final data = await _repo.getShortEpg(ch.streamId.toString(), limit: 8);
          final listings = data['epg_listings'] as List?;
          if (listings == null) return;
          for (final raw in listings) {
            final prog = raw as Map<String, dynamic>;
            final startEpoch = int.tryParse(prog['start_timestamp']?.toString() ?? '');
            final endEpoch = int.tryParse(prog['stop_timestamp']?.toString() ?? '');
            if (startEpoch == null || endEpoch == null) continue;
            final startUtc = DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000, isUtc: true);
            final endUtc = DateTime.fromMillisecondsSinceEpoch(endEpoch * 1000, isUtc: true);
            // Only past programs (ended), within the last 24h
            if (endUtc.isAfter(now) || now.difference(endUtc).inHours > 24) continue;
            final durationMin = endUtc.difference(startUtc).inMinutes;
            if (durationMin <= 0) continue;
            final title = prog['title']?.toString() ?? '';
            if (title.isEmpty) continue;
            programs.add(CatchupProgram(
              streamId: ch.streamId.toString(),
              channelName: ch.name,
              channelIcon: ch.displayIcon,
              title: title,
              description: prog['description']?.toString() ?? '',
              startUtc: startUtc,
              endUtc: endUtc,
              durationMin: durationMin,
              serverLocalStart: prog['start']?.toString() ?? '',
            ));
          }
        } catch (_) {
          // Skip channels where EPG fails
        }
      });
      await Future.wait(futures);

      // Sort by end time (most recent first), take top 20
      programs.sort((a, b) => b.endUtc.compareTo(a.endUtc));
      if (mounted) setState(() => _catchupPrograms = programs.take(20).toList());
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Failed to load catch-up programs', error: e, stackTrace: st);
    }
  }

  Future<void> _loadStreams(String categoryId) async {
    setState(() {
      _selectedCategory = categoryId;
      _loadingStreams = true;
      _searchQuery = '';
      _searchCtrl.clear();
      _selectionMode = false;
      _selectedItems = {};
    });
    try {
      _streams = switch (_mode) {
        ContentMode.live   => await _repo.getLiveStreams(categoryId),
        ContentMode.vod    => await _repo.getVodStreams(categoryId),
        ContentMode.series => await _repo.getSeries(categoryId),
      };
      _resetPagination();
      setState(() => _loadingStreams = false);
    } catch (e) {
      setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loadingStreams = false; });
    }
  }

  void _resetPagination() {
    ref.read(paginatedStreamsProvider.notifier).reset(
      _sortedStreams,
      pageSize: pageSizeForMode(_mode),
    );
  }

  void _resetPaginationIfActive() {
    if (_selectedCategory != null && !_selectedCategory!.startsWith('__') && _streams.isNotEmpty) {
      // Schedule after build so _sortedStreams reflects the new sort
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetPagination();
      });
    }
  }

  // ── Navigation ──
  void _playStream(dynamic stream) {
    final name = getStreamName(stream);
    final displayName = name.isEmpty ? AppLocalizations.of(context)!.sansTitre : name;
    AppLogger.breadcrumb('player', 'Stream play requested', data: {'title': displayName, 'mode': _mode.key});

    if (_mode == ContentMode.series) {
      final seriesId = stream is SeriesItem ? stream.seriesId.toString() : (stream as Map<String, dynamic>)['series_id'].toString();
      final cover = stream is SeriesItem ? stream.displayIcon : (stream as Map<String, dynamic>)['cover']?.toString() ?? '';
      WatchProgress.saveHistory('series:$seriesId', displayName, cover, '', _mode.key);
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: seriesId,
        title: displayName,
        cover: cover,
        rating: stream is SeriesItem ? stream.rating : (stream is Map<String, dynamic> ? stream['rating']?.toString() : null),
        categoryName: stream is SeriesItem ? stream.categoryName : (stream is Map<String, dynamic> ? stream['category_name']?.toString() : null),
        plot: stream is SeriesItem ? (stream.plot ?? stream.description) : (stream is Map<String, dynamic> ? (stream['plot']?.toString() ?? stream['description']?.toString()) : null),
      ))).then((_) => _refreshProgress());
      return;
    }

    // VOD → detail screen
    if (_mode == ContentMode.vod) {
      final vodItem = stream is VodItem
          ? stream
          : VodItem.fromJson(Map<String, dynamic>.from(streamToMap(stream)));
      Navigator.push(context, slideRoute(VodDetailScreen(vod: vodItem)))
          .then((_) => _refreshProgress());
      return;
    }

    final String url;
    final String? resumeKey;
    final cover = getStreamIcon(stream);
    final streamId = getStreamId(stream);
    if (_mode == ContentMode.live) {
      url = _repo.getLiveStreamUrl(streamId);
      resumeKey = null;
    } else {
      final ext = stream is VodItem ? stream.containerExtension : (stream is Map<String, dynamic> ? (stream['container_extension'] ?? 'mp4') : 'mp4');
      url = _repo.getVodStreamUrl(streamId, ext);
      resumeKey = streamId;
      WatchProgress.saveMeta(resumeKey, displayName,
          stream is VodItem ? (stream.streamIcon ?? '') : (stream is Map<String, dynamic> ? (stream['stream_icon']?.toString() ?? '') : ''), url, _mode.key);
    }
    WatchProgress.saveHistory('${_mode.key}:$streamId', displayName, cover, url, _mode.key);

    List<Map<String, dynamic>>? channelList;
    int? channelIndex;
    if (_mode == ContentMode.live) {
      channelList = _sortedStreams.map((e) => streamToMap(e)).toList();
      channelIndex = channelList.indexWhere((ch) => ch['stream_id']?.toString() == streamId);
      if (channelIndex < 0) channelIndex = null;
    }

    Navigator.push(context, slideRoute(PlayerScreen(
      url: url, title: displayName,
      streamId: _mode == ContentMode.live ? streamId : null,
      resumeKey: resumeKey,
      coverUrl: _mode == ContentMode.live
          ? (stream is Channel ? stream.streamIcon : (stream is Map<String, dynamic> ? stream['stream_icon']?.toString() : null))
          : cover.isNotEmpty ? cover : null,
      channelList: channelList,
      channelIndex: channelIndex,
    ))).then((_) => _refreshProgress());
  }

  void _refreshProgress() {
    ref.invalidate(watchProgressProvider);
    ref.invalidate(continueWatchingProvider);
  }

  String? _progressKey(dynamic stream) {
    if (_mode == ContentMode.live) return null;
    return getStreamId(stream);
  }

  void _showShortcutsHelp() => showShortcutsDialog(context);

  Future<void> _openSettings() async {
    final reload = await Navigator.push<bool>(
        context, slideRoute(const SettingsScreen()));
    if (reload == true) {
      setState(() { _loading = true; _error = null; _categories = <cat.Category>[]; _streams = []; _selectedCategory = null; });
      ref.read(favoritesProvider.notifier).load();
      ref.read(watchlistProvider.notifier).load();
      _refreshProgress();
      _init();
    }
  }

  void _showStreamInfoDialog(dynamic s) {
    // For live channels, navigate to channel detail screen
    if (_mode == ContentMode.live) {
      final channel = s is Channel
          ? s
          : Channel.fromJson(streamToMap(s).map((k, v) => MapEntry(k, v)));
      Navigator.push(context, slideRoute(ChannelDetailScreen(channel: channel)));
      return;
    }
    final map = streamToMap(s);
    showStreamInfoDialogWithEpg(
      context,
      stream: map,
      mode: _mode,
      onAddToCollection: () => _showAddToCollectionPicker(s),
      getCachedEpgNow: (streamId) => _repo.getCachedEpgNow(streamId),
      getShortEpg: (streamId, {int limit = 1}) => _repo.getShortEpg(streamId, limit: limit),
    );
  }

  Widget _buildSidebarDrawer(List<CollectionData> collections, List<cat.Category> categories) {
    final tc = AppThemeColors.of(context);
    return Drawer(
      backgroundColor: tc.surface,
      child: SafeArea(
        child: CategorySidebar(
          width: 280,
          minWidth: 280,
          maxWidth: 280,
          onWidthChanged: (_) {},
          onDragEnd: () {},
          categories: categories,
          collections: collections,
          mode: _mode,
          selectedCategory: _selectedCategory,
          progress: ref.read(watchProgressProvider).valueOrNull ?? {},
          favItems: ref.read(favoritesProvider).items,
          wlItems: ref.read(watchlistProvider).items,
          onCategorySelected: (id) {
            Navigator.pop(context);
            _loadStreams(id);
          },
          onSpecialCategorySelected: (cat, items) {
            Navigator.pop(context);
            setState(() {
              _selectedCategory = cat;
              _streams = items;
            });
          },
          onHistoryTap: () {
            Navigator.pop(context);
            Navigator.push(context, fadeRoute(const HistoryScreen()))
                .then((_) => _refreshProgress());
          },
          onCreateCollection: () {
            Navigator.pop(context);
            _createCollection();
          },
          onCollectionSelected: (colId) {
            Navigator.pop(context);
            final cols = ref.read(collectionsProvider);
            final col = cols.firstWhere((c) => c.id == colId, orElse: () => const CollectionData(id: '', name: ''));
            final colItems = col.items
                .where((e) => e.mode == _mode.key)
                .map((e) => e.toJson())
                .toList();
            setState(() {
              _selectedCategory = '__col_${colId}__';
              _streams = colItems;
            });
          },
          onDeleteCollection: (colId) async {
            await ref.read(collectionsProvider.notifier).delete(colId);
            if (_selectedCategory == '__col_${colId}__') {
              setState(() { _selectedCategory = null; _streams = []; });
            }
          },
        ),
      ),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final showGrid = _gridView && _mode != ContentMode.live;

    // Watch connectivity — default to online so the app always attempts connection.
    // On Linux, connectivity_plus may report 'none' if NetworkManager is absent.
    final connectivityAsync = ref.watch(connectivityProvider);
    final connectivityStatus = connectivityAsync.valueOrNull ?? ConnectivityStatus.online;
    final isOffline = connectivityStatus == ConnectivityStatus.offline && _streams.isEmpty;

    // Handle offline -> online transitions: auto-retry + snackbar
    if (_prevConnectivity == ConnectivityStatus.offline &&
        connectivityStatus == ConnectivityStatus.online) {
      // Schedule after build to avoid setState-during-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showAppSnackBar(context, AppLocalizations.of(context)!.connexionRetablie);
          _retryConnection();
        }
      });
    }
    _prevConnectivity = connectivityStatus;

    // Watch providers
    final favState = ref.watch(favoritesProvider);
    final favKeys = favState.keys;
    final favItems = favState.items;
    final wlState = ref.watch(watchlistProvider);
    final wlKeys = wlState.keys;
    final wlItems = wlState.items;
    final progress = ref.watch(watchProgressProvider).valueOrNull ?? {};
    final continueItems = ref.watch(continueWatchingProvider).valueOrNull ?? [];
    final collections = ref.watch(collectionsProvider);

    // Parental controls: filter categories and streams when locked
    final parental = ref.watch(parentalProvider);
    final parentalActive = parental.isEnabled && !parental.isUnlocked;
    final blockedIds = parental.blockedCategoryIds;
    final filteredCategories = parentalActive
        ? _categories.where((c) => !blockedIds.contains(c.categoryId)).toList()
        : _categories;

    return HomeKeyboardHandler(
      onSettings: _openSettings,
      onSearch: () => Navigator.push(context, fadeRoute(const SearchScreen()))
          .then((_) => _refreshProgress()),
      onHistory: () => Navigator.push(context, fadeRoute(const HistoryScreen()))
          .then((_) => _refreshProgress()),
      onEpgGrid: () => Navigator.push(context, slideRoute(EpgGridScreen(
        initialCategoryId: _mode == ContentMode.live ? _selectedCategory : null,
      ))),
      onShortcutsHelp: _showShortcutsHelp,
      selectedCategory: _selectedCategory,
      isLiveMode: _mode == ContentMode.live,
      child: Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebarDrawer(collections, filteredCategories),
      appBar: HomeAppBar(
        mode: _mode,
        showGrid: showGrid,
        sortMode: _sortMode,
        selectedCategory: _selectedCategory,
        leadingMenuButton: MediaQuery.of(context).size.width < 600
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        onModeChanged: (newMode) {
          setState(() { _mode = newMode; _streams = []; _selectedCategory = null; _recentlyAdded = []; _catchupPrograms = []; _selectionMode = false; _selectedItems = {}; });
          AppLogger.breadcrumb('navigation', 'Content mode changed', data: {'mode': newMode.key});
          _loadGridView();
          _loadSortMode();
          _loadCategories();
        },
        onGridToggle: () { setState(() => _gridView = !_gridView); _saveGridView(); },
        onSortChanged: (v) { setState(() => _sortMode = v); _saveSortMode(); _resetPaginationIfActive(); },
        onEpgPressed: () => Navigator.push(context,
            slideRoute(EpgGridScreen(
              initialCategoryId: _mode == ContentMode.live ? _selectedCategory : null,
            ))),
        onSearchPressed: () => Navigator.push(context,
            fadeRoute(const SearchScreen()))
            .then((_) => _refreshProgress()),
        onSettingsPressed: _openSettings,
        onShortcutsPressed: _showShortcutsHelp,
        onProfileChanged: (id) async {
          await ref.read(configProvider.notifier).switchProfile(id);
          ref.read(favoritesProvider.notifier).load();
          ref.read(watchlistProvider.notifier).load();
          _refreshProgress();
          setState(() { _loading = true; _error = null; _categories = <cat.Category>[]; _streams = []; _selectedCategory = null; });
          _init();
        },
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _init, child: Text(AppLocalizations.of(context)!.reessayer)),
            ]))
          : isOffline
          ? OfflineContent(onRetryConnection: _retryConnection)
          : Column(children: [
              ContinueWatchingRow(
                items: continueItems,
                onTap: (item) => Navigator.push(context, slideRoute(
                  PlayerScreen(
                    url: item.url,
                    title: item.name,
                    resumeKey: item.id,
                  ),
                )).then((_) => _refreshProgress()),
              ),
              if (_mode == ContentMode.live)
                CatchupRow(
                  programs: _catchupPrograms,
                  onTap: (prog) {
                    // Build timeshift URL and launch player in catch-up mode
                    String url;
                    if (prog.serverLocalStart.isNotEmpty) {
                      url = _repo.getTimeshiftUrlFromLocal(prog.streamId, prog.serverLocalStart, prog.durationMin);
                    } else {
                      url = _repo.getTimeshiftUrl(prog.streamId, prog.startUtc, prog.durationMin);
                    }
                    Navigator.push(context, slideRoute(PlayerScreen(
                      url: url,
                      title: '${prog.title} (${AppLocalizations.of(context)!.replay})',
                      streamId: prog.streamId,
                      isCatchup: true,
                    )));
                  },
                ),
              RecentlyAddedRow(
                items: parentalActive
                    ? _recentlyAdded.where((item) =>
                        !blockedIds.contains(getStreamCategoryId(item))).toList()
                    : _recentlyAdded,
                mode: _mode,
                onTap: _playStream,
              ),
              Expanded(child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return Row(children: [
              if (isWide) CategorySidebar(
                width: _sidebarWidth,
                minWidth: _sidebarMin,
                maxWidth: _sidebarMax,
                onWidthChanged: (delta) {
                  setState(() => _sidebarWidth = (_sidebarWidth + delta).clamp(_sidebarMin, _sidebarMax));
                },
                onDragEnd: _saveSidebarWidth,
                categories: filteredCategories,
                collections: collections,
                mode: _mode,
                selectedCategory: _selectedCategory,
                progress: progress,
                favItems: favItems,
                wlItems: wlItems,
                onCategorySelected: _loadStreams,
                onSpecialCategorySelected: (cat, items) {
                  setState(() {
                    _selectedCategory = cat;
                    _streams = items;
                  });
                },
                onHistoryTap: () => Navigator.push(context,
                    fadeRoute(const HistoryScreen()))
                    .then((_) => _refreshProgress()),
                onCreateCollection: _createCollection,
                onCollectionSelected: (colId) {
                  final cols = ref.read(collectionsProvider);
                  final col = cols.firstWhere((c) => c.id == colId, orElse: () => const CollectionData(id: '', name: ''));
                  final colItems = col.items
                      .where((e) => e.mode == _mode.key)
                      .map((e) => e.toJson())
                      .toList();
                  setState(() {
                    _selectedCategory = '__col_${colId}__';
                    _streams = colItems;
                  });
                },
                onDeleteCollection: (colId) async {
                  await ref.read(collectionsProvider.notifier).delete(colId);
                  if (_selectedCategory == '__col_${colId}__') {
                    setState(() { _selectedCategory = null; _streams = []; });
                  }
                },
              ),
              // Stream content area
              Expanded(
                child: Builder(builder: (context) {
                  final pagState = ref.watch(paginatedStreamsProvider);
                  // Use paginated visible items if pagination is active (totalCount > 0
                  // and streams match), otherwise fall back to full list for special
                  // categories like favorites/watchlist/collections.
                  final usePagination = pagState.totalCount > 0 &&
                      !_loadingStreams &&
                      _selectedCategory != null &&
                      !_selectedCategory!.startsWith('__') &&
                      _searchQuery.isEmpty;
                  var displayStreams = usePagination
                      ? pagState.visibleItems
                      : _sortedStreams;
                  // Filter out streams from blocked parental categories
                  if (parentalActive) {
                    displayStreams = displayStreams.where((s) {
                      final catId = getStreamCategoryId(s);
                      return catId == null || !blockedIds.contains(catId);
                    }).toList();
                  }
                  return StreamListView(
                    mode: _mode,
                    selectedCategory: _selectedCategory,
                    loadingStreams: _loadingStreams,
                    showGrid: showGrid,
                    sortedStreams: displayStreams,
                    searchQuery: _searchQuery,
                    searchCtrl: _searchCtrl,
                    onSearchChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    onClearSearch: () => setState(() { _searchQuery = ''; _searchCtrl.clear(); }),
                    progress: progress,
                    favKeys: favKeys,
                    wlKeys: wlKeys,
                    selectionMode: _selectionMode,
                    selectedItems: _selectedItems,
                    onEnterSelectionMode: _enterSelectionMode,
                    onExitSelectionMode: _exitSelectionMode,
                    onSelectAll: () {
                      setState(() {
                        if (_selectedItems.length == _streams.length) {
                          _selectedItems = {};
                        } else {
                          _selectedItems = _streams
                              .map((s) => _itemSelectionKey(s)).toSet();
                        }
                      });
                    },
                    onCreateCollectionFromSelected: _createCollectionFromSelected,
                    onToggleSelection: (key) {
                      setState(() {
                        if (_selectedItems.contains(key)) _selectedItems.remove(key);
                        else _selectedItems.add(key);
                      });
                    },
                    activeCollectionId: _activeCollectionId,
                    onPlayStream: _playStream,
                    onToggleFavorite: _toggleFavorite,
                    onToggleWatchlist: _toggleWatchlist,
                    onShowStreamInfo: _showStreamInfoDialog,
                    onRemoveFromCollection: _removeFromCollection,
                    favKeyBuilder: _favKey,
                    itemSelectionKeyBuilder: _itemSelectionKey,
                    progressKeyBuilder: _progressKey,
                    onRefresh: _selectedCategory != null ? () async {
                      await _loadStreams(_selectedCategory!);
                    } : null,
                    hasMore: usePagination ? pagState.hasMore : false,
                    totalCount: usePagination ? pagState.totalCount : _streams.length,
                    isLoadingMore: usePagination ? pagState.isLoadingMore : false,
                    onLoadMore: usePagination
                        ? () => ref.read(paginatedStreamsProvider.notifier).loadMore()
                        : null,
                  );
                }),
              ),
            ]);
                },
              )),
          ]),
    ),
    );
  }

}
