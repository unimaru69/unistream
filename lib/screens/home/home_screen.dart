import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/storage_keys.dart';
import '../../models/app_config.dart';
import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../models/vod_item.dart';
import '../../models/series_item.dart';
import '../../services/xtream_api.dart';
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
import '../settings_screen.dart';
import '../series_detail_screen.dart';
import '../player/player_screen.dart';
import '../history_screen.dart';
import '../epg/epg_grid_screen.dart';
import '../search_screen.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/stream_list.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/collection_dialogs.dart';
import 'widgets/shortcuts_dialog.dart';
import 'widgets/offline_content.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<cat.Category> _categories = [];
  List<dynamic> _streams    = [];
  String? _selectedCategory;
  bool _loading        = true;
  bool _loadingStreams  = false;
  String? _error;
  ContentMode _mode = ContentMode.live;
  bool _isOffline = false;

  // Recently added (VOD/Series)
  List<Map<String, dynamic>> _recentlyAdded = [];

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
  String get _gridViewKey => StorageKeys.gridView(AppConfig.activeProfileId, _mode.key);
  Future<void> _loadGridView() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getBool(_gridViewKey);
    if (v != null) setState(() => _gridView = v);
  }
  Future<void> _saveGridView() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_gridViewKey, _gridView);
  }

  // ── Sort preference per mode ──
  String get _sortKey => StorageKeys.sortMode(AppConfig.activeProfileId, _mode.key);
  Future<void> _loadSortMode() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_sortKey);
    if (v != null) setState(() => _sortMode = v);
  }
  Future<void> _saveSortMode() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_sortKey, _sortMode);
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
    final item = <String, dynamic>{'key': key, 'name': name.isEmpty ? AppLocalizations.of(context)!.sansTitre : name, 'cover': cover, 'mode': _mode.key};

    final collections = ref.read(collectionsProvider);
    final modeCols = collections.where((c) =>
        c['mode'] == null || c['mode'] == _mode.key).toList();
    if (modeCols.isEmpty) {
      await _createCollection();
      final updated = ref.read(collectionsProvider).where((c) =>
          c['mode'] == null || c['mode'] == _mode.key).toList();
      if (updated.isEmpty) return;
    }

    if (!mounted) return;
    final currentModeCols = ref.read(collectionsProvider).where((c) =>
        c['mode'] == null || c['mode'] == _mode.key).toList();
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
        final colName = cols.firstWhere((c) => c['id'] == colId, orElse: () => {'name': 'collection'})['name'];
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
    final col = collections.firstWhere((c) => c['id'] == colId, orElse: () => <String, dynamic>{});
    final colItems = ((col['items'] as List?) ?? [])
        .where((e) => col['mode'] != null || e['mode'] == _mode.key)
        .map((e) => Map<String, dynamic>.from(e))
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
    final colId = col['id'] as String;
    for (final s in items) {
      final key = _favKey(_mode.key, s);
      final itemName = getStreamName(s);
      final cover = getStreamIcon(s);
      final item = <String, dynamic>{'key': key, 'name': itemName.isEmpty ? AppLocalizations.of(context)!.sansTitre : itemName, 'cover': cover, 'mode': _mode.key};
      await ref.read(collectionsProvider.notifier).addItem(colId, item);
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
    final p = await SharedPreferences.getInstance();
    final w = p.getDouble(StorageKeys.sidebarWidth);
    if (w != null) setState(() => _sidebarWidth = w.clamp(_sidebarMin, _sidebarMax));
  }
  Future<void> _saveSidebarWidth() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(StorageKeys.sidebarWidth, _sidebarWidth);
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
    ref.read(favoritesProvider.notifier).toggle(key, {...map, '_mode': _mode.key});
  }

  void _toggleWatchlist(dynamic stream) {
    final key = _favKey(_mode.key, stream);
    final map = streamToMap(stream);
    ref.read(watchlistProvider.notifier).toggle(key, {...map, '_mode': _mode.key});
  }

  // ── Init / loading ──
  Future<void> _init() async {
    try {
      final auth = await XtreamApi.authenticate();
      if (auth['user_info']?['auth'] == 1) {
        XtreamApi.loadServerTimezone();
        setState(() => _isOffline = false);
        await _loadCategories();
      } else {
        setState(() { _error = AppLocalizations.of(context)!.authEchouee; _loading = false; });
      }
    } catch (e) {
      setState(() { _isOffline = true; _loading = false; _error = null; });
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
        ContentMode.live   => await XtreamApi.getLiveCategoriesTyped(),
        ContentMode.vod    => await XtreamApi.getVodCategoriesTyped(),
        ContentMode.series => await XtreamApi.getSeriesCategoriesTyped(),
      };
      setState(() => _loading = false);
      _loadRecentlyAdded();
    } catch (e) {
      setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _loading = false; });
    }
  }

  Future<void> _loadRecentlyAdded() async {
    if (_mode == ContentMode.live) {
      setState(() => _recentlyAdded = []);
      return;
    }
    try {
      final List<dynamic> all = _mode == ContentMode.vod
          ? await XtreamApi.getVodStreamsTyped()
          : await XtreamApi.getSeriesTyped();
      final items = all.where((s) {
        final added = (s is VodItem ? s.added : s is SeriesItem ? s.added : null)?.toString() ?? '0';
        final lastMod = (s is VodItem ? s.lastModified : s is SeriesItem ? s.lastModified : null)?.toString() ?? '0';
        return (added.isNotEmpty && added != '0') || (lastMod.isNotEmpty && lastMod != '0');
      }).map((s) => streamToMap(s)).toList();
      items.sort((a, b) {
        final ta = int.tryParse(a['added']?.toString() ?? '0') ?? 0;
        final tb = int.tryParse(b['added']?.toString() ?? '0') ?? 0;
        final ma = int.tryParse(a['last_modified']?.toString() ?? '0') ?? 0;
        final mb = int.tryParse(b['last_modified']?.toString() ?? '0') ?? 0;
        final sa = ta > ma ? ta : ma;
        final sb = tb > mb ? tb : mb;
        return sb.compareTo(sa);
      });
      if (mounted) setState(() => _recentlyAdded = items.take(20).toList());
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'Failed to load recently added items', error: e, stackTrace: st);
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
        ContentMode.live   => await XtreamApi.getLiveStreamsTyped(categoryId),
        ContentMode.vod    => await XtreamApi.getVodStreamsTyped(categoryId),
        ContentMode.series => await XtreamApi.getSeriesTyped(categoryId),
      };
      setState(() => _loadingStreams = false);
    } catch (e) {
      setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _loadingStreams = false; });
    }
  }

  // ── Navigation ──
  void _playStream(dynamic stream) {
    final name = getStreamName(stream);
    final displayName = name.isEmpty ? AppLocalizations.of(context)!.sansTitre : name;

    if (_mode == ContentMode.series) {
      final seriesId = stream is SeriesItem ? stream.seriesId.toString() : (stream as Map<String, dynamic>)['series_id'].toString();
      final cover = stream is SeriesItem ? stream.displayIcon : (stream as Map<String, dynamic>)['cover']?.toString() ?? '';
      WatchProgress.saveHistory('series:$seriesId', displayName, cover, '', _mode.key);
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: seriesId,
        title: displayName,
        cover: cover,
      ))).then((_) => _refreshProgress());
      return;
    }

    final String url;
    final String? resumeKey;
    final cover = getStreamIcon(stream);
    final streamId = getStreamId(stream);
    if (_mode == ContentMode.live) {
      url = XtreamApi.getLiveStreamUrl(streamId);
      resumeKey = null;
    } else {
      final ext = stream is VodItem ? stream.containerExtension : (stream is Map<String, dynamic> ? (stream['container_extension'] ?? 'mp4') : 'mp4');
      url = XtreamApi.getVodStreamUrl(streamId, ext);
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
    final map = streamToMap(s);
    showStreamInfoDialogWithEpg(
      context,
      stream: map,
      mode: _mode,
      onAddToCollection: () => _showAddToCollectionPicker(s),
      getCachedEpgNow: (streamId) => XtreamApi.getCachedEpgNow(streamId),
      getShortEpg: (streamId, {int limit = 1}) => XtreamApi.getShortEpg(streamId, limit: limit),
    );
  }

  Widget _buildSidebarDrawer(List<Map<String, dynamic>> collections) {
    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: SafeArea(
        child: CategorySidebar(
          width: 280,
          minWidth: 280,
          maxWidth: 280,
          onWidthChanged: (_) {},
          onDragEnd: () {},
          categories: _categories,
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
            final col = cols.firstWhere((c) => c['id'] == colId, orElse: () => <String, dynamic>{});
            final colItems = ((col['items'] as List?) ?? [])
                .where((e) => e['mode'] == _mode.key)
                .map((e) => Map<String, dynamic>.from(e))
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

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final meta = HardwareKeyboard.instance.isMetaPressed;
        if (!meta) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.keyQ) {
          exit(0);
        }
        if (key == LogicalKeyboardKey.comma) {
          _openSettings();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyF) {
          Navigator.push(context, fadeRoute(const SearchScreen()))
              .then((_) => _refreshProgress());
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyY) {
          Navigator.push(context, fadeRoute(const HistoryScreen()))
              .then((_) => _refreshProgress());
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyG) {
          Navigator.push(context, slideRoute(EpgGridScreen(
            initialCategoryId: _mode == ContentMode.live ? _selectedCategory : null,
          )));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.question) {
          _showShortcutsHelp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebarDrawer(collections),
      appBar: AppBar(
        title: const Text('UniStream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: MediaQuery.of(context).size.width < 600
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (AppConfig.profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: AppLocalizations.of(context)!.changerProfil,
              onSelected: (id) async {
                await ref.read(configProvider.notifier).switchProfile(id);
                ref.read(favoritesProvider.notifier).load();
                ref.read(watchlistProvider.notifier).load();
                _refreshProgress();
                setState(() { _loading = true; _error = null; _categories = <cat.Category>[]; _streams = []; _selectedCategory = null; });
                _init();
              },
              itemBuilder: (_) => AppConfig.profiles.map((pr) => PopupMenuItem(
                value: pr.id,
                child: Row(children: [
                  Icon(pr.id == AppConfig.activeProfileId ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(pr.name, style: const TextStyle(fontSize: 13)),
                ]),
              )).toList(),
            ),
          ToggleButtons(
            isSelected: [_mode == ContentMode.live, _mode == ContentMode.vod, _mode == ContentMode.series],
            onPressed: (i) {
              final modes = ContentMode.values;
              setState(() { _mode = modes[i]; _streams = []; _selectedCategory = null; _recentlyAdded = <Map<String, dynamic>>[]; _selectionMode = false; _selectedItems = {}; });
              _loadGridView();
              _loadSortMode();
              _loadCategories();
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: AppColors.primaryBlue,
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(AppLocalizations.of(context)!.live)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(AppLocalizations.of(context)!.vod)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(AppLocalizations.of(context)!.series)),
            ],
          ),
          const SizedBox(width: 4),
          if (_mode != ContentMode.live)
            IconButton(
              icon: Icon(showGrid ? Icons.view_list : Icons.grid_view),
              tooltip: showGrid ? AppLocalizations.of(context)!.vueListe : AppLocalizations.of(context)!.vueGrille,
              onPressed: () { setState(() => _gridView = !_gridView); _saveGridView(); },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: AppLocalizations.of(context)!.trier,
            onSelected: (v) { setState(() => _sortMode = v); _saveSortMode(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'default', child: Row(children: [
                Icon(_sortMode == 'default' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), Text(AppLocalizations.of(context)!.ordreParDefaut, style: const TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'alpha', child: Row(children: [
                Icon(_sortMode == 'alpha' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), Text(AppLocalizations.of(context)!.alphabetique, style: const TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'number', child: Row(children: [
                Icon(_sortMode == 'number' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), Text(AppLocalizations.of(context)!.parNumero, style: const TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'favFirst', child: Row(children: [
                Icon(_sortMode == 'favFirst' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), Text(AppLocalizations.of(context)!.favorisPremier, style: const TextStyle(fontSize: 13)),
              ])),
            ],
          ),
          IconButton(icon: const Icon(Icons.live_tv), tooltip: AppLocalizations.of(context)!.guideTV,
              onPressed: () => Navigator.push(context,
                  slideRoute(EpgGridScreen(
                    initialCategoryId: _mode == ContentMode.live ? _selectedCategory : null,
                  )))),
          IconButton(icon: const Icon(Icons.search), tooltip: AppLocalizations.of(context)!.rechercheGlobale,
              onPressed: () => Navigator.push(context,
                  fadeRoute(const SearchScreen()))
                  .then((_) => _refreshProgress())),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings, tooltip: AppLocalizations.of(context)!.parametres),
          IconButton(icon: const Icon(Icons.help_outline, size: 20), onPressed: _showShortcutsHelp, tooltip: '${AppLocalizations.of(context)!.raccourcisClavier} (Cmd+?)'),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _init, child: Text(AppLocalizations.of(context)!.reessayer)),
            ]))
          : _isOffline
          ? OfflineContent(onRetryConnection: _retryConnection)
          : Column(children: [
              ContinueWatchingRow(
                items: continueItems,
                onTap: (item) => Navigator.push(context, slideRoute(
                  PlayerScreen(
                    url: item['url'] as String? ?? '',
                    title: item['name'] as String? ?? '',
                    resumeKey: item['_id'] as String,
                  ),
                )).then((_) => _refreshProgress()),
              ),
              RecentlyAddedRow(
                items: _recentlyAdded,
                mode: _mode,
                onTap: _playStream,
              ),
              Expanded(child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  return Row(children: [
              if (isWide) CategorySidebar(
                width: _sidebarWidth,
                minWidth: _sidebarMin,
                maxWidth: _sidebarMax,
                onWidthChanged: (delta) {
                  setState(() => _sidebarWidth = (_sidebarWidth + delta).clamp(_sidebarMin, _sidebarMax));
                },
                onDragEnd: _saveSidebarWidth,
                categories: _categories,
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
                  final col = cols.firstWhere((c) => c['id'] == colId, orElse: () => <String, dynamic>{});
                  final colItems = ((col['items'] as List?) ?? [])
                      .where((e) => e['mode'] == _mode.key)
                      .map((e) => Map<String, dynamic>.from(e))
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
                child: StreamListView(
                  mode: _mode,
                  selectedCategory: _selectedCategory,
                  loadingStreams: _loadingStreams,
                  showGrid: showGrid,
                  sortedStreams: _sortedStreams,
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
                ),
              ),
            ]);
                },
              )),
          ]),
    ),
    );
  }

}
