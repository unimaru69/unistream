import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import '../../core/strings.dart';
import '../../core/storage_keys.dart';
import '../../models/app_config.dart';
import '../../services/xtream_api.dart';
import '../../services/watch_progress.dart';
import '../../services/collections_service.dart';
import '../../utils/routes.dart';
import '../../models/content_mode.dart';
import '../settings_screen.dart';
import '../series_detail_screen.dart';
import '../player/player_screen.dart';
import '../history_screen.dart';
import '../epg_grid_screen.dart';
import '../search_screen.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/stream_list.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/collection_dialogs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _streams    = [];
  String? _selectedCategory;
  bool _loading        = true;
  bool _loadingStreams  = false;
  String? _error;
  ContentMode _mode = ContentMode.live;
  bool _isOffline = false;

  // Recently added (VOD/Series)
  List<Map<String, dynamic>> _recentlyAdded = [];

  // Favorites
  Set<String> _favKeys = {};
  List<Map<String, dynamic>> _favItems = [];
  String get _prefKeyFavs => StorageKeys.favorites(AppConfig.activeProfileId);

  // Watchlist
  Set<String> _wlKeys = {};
  List<Map<String, dynamic>> _wlItems = [];
  String get _prefKeyWl => StorageKeys.watchlist(AppConfig.activeProfileId);

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Progress (id -> ratio 0-1)
  Map<String, double> _progress = {};

  // Continue watching
  List<Map<String, dynamic>> _continueItems = [];

  // Grid view (VOD + Series only)
  bool _gridView = false;

  // Sort mode
  String _sortMode = 'default';

  // Collections
  List<Map<String, dynamic>> _collections = [];

  // Selection mode
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

  // Sidebar width (resizable)
  double _sidebarWidth = 250;
  static const double _sidebarMin = 150;
  static const double _sidebarMax = 400;

  @override
  void initState() {
    super.initState();
    _loadFavorites().then((_) => _loadWatchlist().then((_) => _init()));
    _refreshProgress();
    _loadSidebarWidth();
    _loadGridView();
    _loadSortMode();
    _loadCollections();
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
  Future<void> _loadCollections() async {
    final cols = await CollectionsService.loadCollections();
    if (mounted) setState(() => _collections = cols);
  }

  Future<void> _createCollection() async {
    final name = await showCreateCollectionDialog(context);
    if (name != null && name.isNotEmpty) {
      await CollectionsService.saveCollection(name, mode: _mode.key);
      await _loadCollections();
    }
  }

  Future<void> _showAddToCollectionPicker(Map<String, dynamic> stream) async {
    final key = _favKey(_mode.key, stream);
    final name = stream['name'] ?? 'Sans titre';
    final cover = stream['stream_icon']?.toString() ?? stream['cover']?.toString() ?? '';
    final item = <String, dynamic>{'key': key, 'name': name, 'cover': cover, 'mode': _mode.key};

    final modeCols = _collections.where((c) =>
        c['mode'] == null || c['mode'] == _mode.key).toList();
    if (modeCols.isEmpty) {
      await _createCollection();
      await _loadCollections();
      final updated = _collections.where((c) =>
          c['mode'] == null || c['mode'] == _mode.key).toList();
      if (updated.isEmpty) return;
    }

    if (!mounted) return;
    final currentModeCols = _collections.where((c) =>
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
      await CollectionsService.addToCollection(colId, item);
      await _loadCollections();
      if (mounted) {
        final colName = _collections.firstWhere((c) => c['id'] == colId, orElse: () => {'name': 'collection'})['name'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ajoute a "$colName"'),
          backgroundColor: AppColors.darkSurface,
        ));
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

  Future<void> _removeFromCollection(Map<String, dynamic> s) async {
    final colId = _activeCollectionId;
    if (colId == null) return;
    final key = s['key']?.toString() ?? _favKey(_mode.key, s);
    await CollectionsService.removeFromCollection(colId, key);
    await _loadCollections();
    final col = _collections.firstWhere((c) => c['id'] == colId, orElse: () => <String, dynamic>{});
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

  String _itemSelectionKey(Map<String, dynamic> s) {
    return _favKey(_mode.key, s);
  }

  Future<void> _createCollectionFromSelected() async {
    final items = _streams.cast<Map<String, dynamic>>()
        .where((s) => _selectedItems.contains(_itemSelectionKey(s)))
        .toList();
    if (items.isEmpty) return;

    final name = await showCreateCollectionFromSelectedDialog(context, itemCount: items.length);
    if (name == null || name.isEmpty) return;
    final col = await CollectionsService.saveCollection(name, mode: _mode.key);
    final colId = col['id'] as String;
    for (final s in items) {
      final key = _favKey(_mode.key, s);
      final itemName = s['name'] ?? 'Sans titre';
      final cover = s['stream_icon']?.toString() ?? s['cover']?.toString() ?? '';
      final item = <String, dynamic>{'key': key, 'name': itemName, 'cover': cover, 'mode': _mode.key};
      await CollectionsService.addToCollection(colId, item);
    }
    await _loadCollections();
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Collection "$name" créée avec ${items.length} éléments'),
        backgroundColor: AppColors.darkSurface,
      ));
    }
  }

  List<dynamic> get _sortedStreams {
    if (_sortMode == 'default') return _streams;
    final list = List<dynamic>.from(_streams);
    switch (_sortMode) {
      case 'alpha':
        list.sort((a, b) => (a['name'] ?? '').toString().toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
      case 'number':
        list.sort((a, b) {
          final na = int.tryParse((a['num'] ?? '0').toString()) ?? 0;
          final nb = int.tryParse((b['num'] ?? '0').toString()) ?? 0;
          return na.compareTo(nb);
        });
        break;
      case 'favFirst':
        list.sort((a, b) {
          final aFav = _favKeys.contains(_favKey(_mode.key, a as Map<String, dynamic>)) ? 0 : 1;
          final bFav = _favKeys.contains(_favKey(_mode.key, b as Map<String, dynamic>)) ? 0 : 1;
          if (aFav != bFav) return aFav.compareTo(bFav);
          return (a['name'] ?? '').toString().toLowerCase()
              .compareTo((b['name'] ?? '').toString().toLowerCase());
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

  // ── Favorites ──
  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefKeyFavs);
    if (raw != null) {
      final list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
      setState(() {
        _favItems = list;
        _favKeys  = list.map((e) => e['_key'] as String).toSet();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKeyFavs, jsonEncode(_favItems));
  }

  String _favKey(String mode, Map<String, dynamic> s) {
    final id = mode == 'series' ? s['series_id']?.toString() : s['stream_id']?.toString();
    return '$mode:$id';
  }

  void _toggleFavorite(Map<String, dynamic> stream) {
    final key = _favKey(_mode.key, stream);
    setState(() {
      if (_favKeys.contains(key)) {
        _favKeys.remove(key);
        _favItems.removeWhere((e) => e['_key'] == key);
      } else {
        _favKeys.add(key);
        _favItems.add({...stream, '_key': key, '_mode': _mode.key});
      }
    });
    _saveFavorites();
  }

  // ── Watchlist ──
  Future<void> _loadWatchlist() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefKeyWl);
    if (raw != null) {
      final list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
      setState(() {
        _wlItems = list;
        _wlKeys  = list.map((e) => e['_key'] as String).toSet();
      });
    }
  }

  Future<void> _saveWatchlist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKeyWl, jsonEncode(_wlItems));
  }

  void _toggleWatchlist(Map<String, dynamic> stream) {
    final key = _favKey(_mode.key, stream);
    setState(() {
      if (_wlKeys.contains(key)) {
        _wlKeys.remove(key);
        _wlItems.removeWhere((e) => e['_key'] == key);
      } else {
        _wlKeys.add(key);
        _wlItems.add({...stream, '_key': key, '_mode': _mode.key});
      }
    });
    _saveWatchlist();
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
        setState(() { _error = 'Authentification échouée'; _loading = false; });
      }
    } catch (e) {
      setState(() { _isOffline = true; _loading = false; _error = null; });
      _refreshProgress();
    }
  }

  Future<void> _retryConnection() async {
    setState(() { _loading = true; _error = null; });
    _loadFavorites().then((_) => _loadWatchlist().then((_) => _init()));
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      _categories = switch (_mode) {
        ContentMode.live   => await XtreamApi.getLiveCategories(),
        ContentMode.vod    => await XtreamApi.getVodCategories(),
        ContentMode.series => await XtreamApi.getSeriesCategories(),
      };
      setState(() => _loading = false);
      _loadRecentlyAdded();
    } catch (e) {
      setState(() { _error = XtreamApi.friendlyError(e); _loading = false; });
    }
  }

  Future<void> _loadRecentlyAdded() async {
    if (_mode == ContentMode.live) {
      setState(() => _recentlyAdded = []);
      return;
    }
    try {
      final List<dynamic> all = _mode == ContentMode.vod
          ? await XtreamApi.getVodStreams()
          : await XtreamApi.getSeries();
      final items = all.cast<Map<String, dynamic>>().where((s) {
        final added = s['added']?.toString() ?? '0';
        final lastMod = s['last_modified']?.toString() ?? '0';
        return (added.isNotEmpty && added != '0') || (lastMod.isNotEmpty && lastMod != '0');
      }).toList();
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
        ContentMode.live   => await XtreamApi.getLiveStreams(categoryId),
        ContentMode.vod    => await XtreamApi.getVodStreams(categoryId),
        ContentMode.series => await XtreamApi.getSeries(categoryId),
      };
      setState(() => _loadingStreams = false);
    } catch (e) {
      setState(() { _error = XtreamApi.friendlyError(e); _loadingStreams = false; });
    }
  }

  // ── Navigation ──
  void _playStream(Map<String, dynamic> stream) {
    final name = stream['name'] ?? 'Sans titre';

    if (_mode == ContentMode.series) {
      final cover = stream['cover']?.toString() ?? '';
      WatchProgress.saveHistory('series:${stream['series_id']}', name, cover, '', _mode.key);
      Navigator.push(context, slideRoute(SeriesDetailScreen(
        seriesId: stream['series_id'].toString(),
        title: name,
        cover: cover,
      ))).then((_) => _refreshProgress());
      return;
    }

    final String url;
    final String? resumeKey;
    final cover = stream['stream_icon']?.toString() ?? stream['cover']?.toString() ?? '';
    if (_mode == ContentMode.live) {
      url = XtreamApi.getLiveStreamUrl(stream['stream_id'].toString());
      resumeKey = null;
    } else {
      url = XtreamApi.getVodStreamUrl(
          stream['stream_id'].toString(), stream['container_extension'] ?? 'mp4');
      resumeKey = stream['stream_id'].toString();
      WatchProgress.saveMeta(resumeKey, name,
          stream['stream_icon']?.toString() ?? '', url, _mode.key);
    }
    WatchProgress.saveHistory('${_mode.key}:${stream['stream_id']}', name, cover, url, _mode.key);

    List<Map<String, dynamic>>? channelList;
    int? channelIndex;
    if (_mode == ContentMode.live) {
      channelList = List<Map<String, dynamic>>.from(_sortedStreams.map((e) => Map<String, dynamic>.from(e)));
      channelIndex = channelList.indexWhere((ch) => ch['stream_id']?.toString() == stream['stream_id']?.toString());
      if (channelIndex < 0) channelIndex = null;
    }

    Navigator.push(context, slideRoute(PlayerScreen(
      url: url, title: name,
      streamId: _mode == ContentMode.live ? stream['stream_id'].toString() : null,
      resumeKey: resumeKey,
      coverUrl: _mode == ContentMode.live
          ? stream['stream_icon']?.toString()
          : stream['stream_icon']?.toString() ?? stream['cover']?.toString(),
      channelList: channelList,
      channelIndex: channelIndex,
    ))).then((_) => _refreshProgress());
  }

  Future<void> _refreshProgress() async {
    final results = await Future.wait([
      WatchProgress.loadAll(),
      WatchProgress.loadContinueWatching(),
    ]);
    if (mounted) setState(() {
      _progress       = results[0] as Map<String, double>;
      _continueItems  = results[1] as List<Map<String, dynamic>>;
    });
  }

  String? _progressKey(Map<String, dynamic> stream) {
    if (_mode == ContentMode.live) return null;
    return _mode == ContentMode.series
        ? stream['series_id']?.toString()
        : stream['stream_id']?.toString();
  }

  void _showShortcutsHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(AppStrings.raccourcisClavier, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _shortcutRow('Cmd+Q', 'Quitter'),
                _shortcutRow('Cmd+,', 'Réglages'),
                _shortcutRow('Cmd+F', 'Rechercher'),
                _shortcutRow('Cmd+Y', 'Historique'),
                _shortcutRow('Cmd+G', 'Guide TV'),
                _shortcutRow('Cmd+?', 'Cette aide'),
                const SizedBox(height: 16),
                const Text('Lecteur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                const Divider(color: Colors.white12, height: 12),
                _shortcutRow('Espace', 'Lecture / Pause'),
                _shortcutRow('\u2190 / \u2192', 'Reculer / Avancer 10s (VOD)'),
                _shortcutRow('\u2191 / \u2193', 'Volume +/- (VOD) / Zapping (Live)'),
                _shortcutRow('F', 'Plein écran'),
                _shortcutRow('M', 'Couper le son'),
                _shortcutRow('Esc', 'Quitter le lecteur'),
                const SizedBox(height: 16),
                const Text('Lecteur Live', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                const Divider(color: Colors.white12, height: 12),
                _shortcutRow('\u2191 / \u2193', 'Chaîne précédente / suivante'),
                _shortcutRow('P / N', 'Chaîne précédente / suivante'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.fermer)),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primaryBlue)),
        ),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70))),
      ]),
    );
  }

  Future<void> _openSettings() async {
    final reload = await Navigator.push<bool>(
        context, slideRoute(const SettingsScreen()));
    if (reload == true) {
      setState(() { _loading = true; _error = null; _categories = []; _streams = []; _selectedCategory = null; });
      _loadFavorites().then((_) => _loadWatchlist().then((_) => _init()));
      _refreshProgress();
    }
  }

  void _showStreamInfoDialog(Map<String, dynamic> s) {
    showStreamInfoDialogWithEpg(
      context,
      stream: s,
      mode: _mode,
      onAddToCollection: () => _showAddToCollectionPicker(s),
      getCachedEpgNow: (streamId) => XtreamApi.getCachedEpgNow(streamId),
      getShortEpg: (streamId, {int limit = 1}) => XtreamApi.getShortEpg(streamId, limit: limit),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final showGrid = _gridView && _mode != ContentMode.live;

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
      appBar: AppBar(
        title: const Text('UniStream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (AppConfig.profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Changer de profil',
              onSelected: (id) async {
                await AppConfig.switchProfile(id);
                setState(() { _loading = true; _error = null; _categories = []; _streams = []; _selectedCategory = null; });
                _loadFavorites().then((_) => _init());
                _refreshProgress();
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
              setState(() { _mode = modes[i]; _streams = []; _selectedCategory = null; _recentlyAdded = []; _selectionMode = false; _selectedItems = {}; });
              _loadGridView();
              _loadSortMode();
              _loadCategories();
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: AppColors.primaryBlue,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Live')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('VOD')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Séries')),
            ],
          ),
          const SizedBox(width: 4),
          if (_mode != ContentMode.live)
            IconButton(
              icon: Icon(showGrid ? Icons.view_list : Icons.grid_view),
              tooltip: showGrid ? 'Vue liste' : 'Vue grille',
              onPressed: () { setState(() => _gridView = !_gridView); _saveGridView(); },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: AppStrings.trier,
            onSelected: (v) { setState(() => _sortMode = v); _saveSortMode(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'default', child: Row(children: [
                Icon(_sortMode == 'default' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), const Text('Ordre par défaut', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'alpha', child: Row(children: [
                Icon(_sortMode == 'alpha' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), const Text('Alphabétique', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'number', child: Row(children: [
                Icon(_sortMode == 'number' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), const Text('Par numéro', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'favFirst', child: Row(children: [
                Icon(_sortMode == 'favFirst' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8), const Text(AppStrings.favorisPremier, style: TextStyle(fontSize: 13)),
              ])),
            ],
          ),
          IconButton(icon: const Icon(Icons.live_tv), tooltip: 'Guide TV',
              onPressed: () => Navigator.push(context,
                  slideRoute(EpgGridScreen(
                    initialCategoryId: _mode == ContentMode.live ? _selectedCategory : null,
                  )))),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Recherche globale',
              onPressed: () => Navigator.push(context,
                  fadeRoute(const SearchScreen()))
                  .then((_) => _refreshProgress())),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings, tooltip: AppStrings.parametres),
          IconButton(icon: const Icon(Icons.help_outline, size: 20), onPressed: _showShortcutsHelp, tooltip: 'Raccourcis clavier (Cmd+?)'),
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
              ElevatedButton(onPressed: _init, child: const Text('Réessayer')),
            ]))
          : _isOffline
          ? _buildOfflineBody()
          : Column(children: [
              ContinueWatchingRow(
                items: _continueItems,
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
              Expanded(child: Row(children: [
              CategorySidebar(
                width: _sidebarWidth,
                minWidth: _sidebarMin,
                maxWidth: _sidebarMax,
                onWidthChanged: (delta) {
                  setState(() => _sidebarWidth = (_sidebarWidth + delta).clamp(_sidebarMin, _sidebarMax));
                },
                onDragEnd: _saveSidebarWidth,
                categories: _categories,
                collections: _collections,
                mode: _mode,
                selectedCategory: _selectedCategory,
                progress: _progress,
                favItems: _favItems,
                wlItems: _wlItems,
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
                  final col = _collections.firstWhere((c) => c['id'] == colId, orElse: () => <String, dynamic>{});
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
                  await CollectionsService.deleteCollection(colId);
                  await _loadCollections();
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
                  progress: _progress,
                  favKeys: _favKeys,
                  wlKeys: _wlKeys,
                  selectionMode: _selectionMode,
                  selectedItems: _selectedItems,
                  onEnterSelectionMode: _enterSelectionMode,
                  onExitSelectionMode: _exitSelectionMode,
                  onSelectAll: () {
                    setState(() {
                      if (_selectedItems.length == _streams.length) {
                        _selectedItems = {};
                      } else {
                        _selectedItems = _streams.cast<Map<String, dynamic>>()
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
                ),
              ),
            ])),
          ]),
    ),
    );
  }

  // ── Offline body ──
  Widget _buildOfflineBody() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.withValues(alpha: 0.15),
        child: Row(children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Mode hors-ligne — Serveur indisponible',
              style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600))),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: _retryConnection,
          ),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_continueItems.isNotEmpty) ...[
            const Text(AppStrings.continuerRegarder,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _continueItems.length,
                itemBuilder: (_, i) {
                  final item  = _continueItems[i];
                  final ratio = item['_ratio'] as double;
                  final cover = item['cover'] as String? ?? '';
                  final name  = item['name']  as String? ?? '';
                  return Tooltip(
                    message: AppStrings.connexionRequise,
                    child: Opacity(
                      opacity: 0.5,
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(fit: StackFit.expand, children: [
                              cover.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.white10),
                                      errorWidget: (_, __, ___) => Container(color: Colors.white10,
                                          child: const Icon(Icons.movie, color: Colors.white24)))
                                  : Container(color: Colors.white10,
                                      child: const Icon(Icons.movie, color: Colors.white24)),
                              Positioned(bottom: 0, left: 0, right: 0,
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: Colors.black45,
                                  color: Colors.amber,
                                  minHeight: 3,
                                ),
                              ),
                              const Center(child: Icon(Icons.cloud_off, color: Colors.white38, size: 20)),
                            ]),
                          )),
                          const SizedBox(height: 3),
                          Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_favItems.isNotEmpty) ...[
            const Text(AppStrings.favoris,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            ...(_favItems.take(20).map((item) {
              final name = item['name'] as String? ?? '';
              final cover = item['cover']?.toString() ?? item['stream_icon']?.toString() ?? '';
              return Tooltip(
                message: AppStrings.connexionRequise,
                child: ListTile(
                  leading: cover.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(imageUrl: cover, width: 40, height: 40, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.star, color: Colors.amber, size: 20)))
                      : const Icon(Icons.star, color: Colors.amber, size: 20),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.cloud_off, color: Colors.white24, size: 16),
                  dense: true,
                  enabled: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            })),
            const SizedBox(height: 24),
          ],
          if (_continueItems.isEmpty && _favItems.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text(AppStrings.aucuneDonneesCache,
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
              ]),
            )),
        ]),
      )),
    ]);
  }
}
