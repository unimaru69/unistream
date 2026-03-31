import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/app_config.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../services/collections_service.dart';
import '../utils/routes.dart';
import '../models/content_mode.dart';
import '../widgets/skeleton_list.dart';
import 'settings_screen.dart';
import 'series_detail_screen.dart';
import 'player_screen.dart';
import 'history_screen.dart';
import 'epg_grid_screen.dart';
import 'search_screen.dart';

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

  // Récemment ajoutés (VOD/Series)
  List<Map<String, dynamic>> _recentlyAdded = [];

  // Favoris
  Set<String> _favKeys = {};
  List<Map<String, dynamic>> _favItems = [];
  String get _prefKeyFavs => 'favorites_${AppConfig.activeProfileId}';

  // Watchlist "À regarder plus tard"
  Set<String> _wlKeys = {};
  List<Map<String, dynamic>> _wlItems = [];
  String get _prefKeyWl => 'watchlist_${AppConfig.activeProfileId}';

  // Recherche
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Progression (id → ratio 0-1)
  Map<String, double> _progress = {};

  // Bandeau "Continuer à regarder"
  List<Map<String, dynamic>> _continueItems = [];

  // Vue grille (VOD + Séries uniquement)
  bool _gridView = false;

  // Tri des chaînes
  String _sortMode = 'default';

  // Collections personnalisées
  List<Map<String, dynamic>> _collections = [];

  // Mode sélection (pour créer une collection depuis favoris/watchlist)
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

  // Largeur sidebar catégories (redimensionnable)
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
  String get _gridViewKey => 'gridView_${AppConfig.activeProfileId}_${_mode.key}';
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
  String get _sortKey => 'sortMode_${AppConfig.activeProfileId}_${_mode.key}';
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
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Nouvelle collection'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Nom',
            filled: true, fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A90D9)),
            child: const Text('Creer'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
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
      // Offer to create one
      await _createCollection();
      await _loadCollections();
      final updated = _collections.where((c) =>
          c['mode'] == null || c['mode'] == _mode.key).toList();
      if (updated.isEmpty) return;
    }

    if (!mounted) return;
    final currentModeCols = _collections.where((c) =>
        c['mode'] == null || c['mode'] == _mode.key).toList();
    final colId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Ajouter a une collection'),
        children: [
          ...currentModeCols.map((col) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, col['id'] as String),
            child: Text(col['name'] as String, style: const TextStyle(fontSize: 14)),
          )),
          const Divider(color: Colors.white12),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await _createCollection();
              // After creating, re-show picker
              if (mounted) _showAddToCollectionPicker(stream);
            },
            child: const Row(children: [
              Icon(Icons.add, size: 18, color: Color(0xFF4A90D9)),
              SizedBox(width: 8),
              Text('Nouvelle collection', style: TextStyle(fontSize: 14, color: Color(0xFF4A90D9))),
            ]),
          ),
        ],
      ),
    );
    if (colId != null) {
      await CollectionsService.addToCollection(colId, item);
      await _loadCollections();
      if (mounted) {
        final colName = _collections.firstWhere((c) => c['id'] == colId, orElse: () => {'name': 'collection'})['name'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ajoute a "$colName"'),
          backgroundColor: const Color(0xFF12122A),
        ));
      }
    }
  }

  /// Returns the collection ID if the current view is a collection, else null.
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
    // Refresh the displayed items
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

    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: Text('Nouvelle collection (${items.length} éléments)'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom de la collection'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Créer')),
        ],
      ),
    );
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
        backgroundColor: const Color(0xFF12122A),
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
    final w = p.getDouble('sidebar_width');
    if (w != null) setState(() => _sidebarWidth = w.clamp(_sidebarMin, _sidebarMax));
  }
  Future<void> _saveSidebarWidth() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('sidebar_width', _sidebarWidth);
  }

  // ── Favoris ──
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

  // ── Init / chargement ──
  Future<void> _init() async {
    try {
      final auth = await XtreamApi.authenticate();
      if (auth['user_info']?['auth'] == 1) {
        // Load server timezone for catch-up URL generation
        XtreamApi.loadServerTimezone(); // fire-and-forget, non-blocking
        setState(() => _isOffline = false);
        await _loadCategories();
      } else {
        setState(() { _error = 'Authentification échouée'; _loading = false; });
      }
    } catch (e) {
      // Go offline: show cached data instead of raw error
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

  // ── Récemment ajoutés (VOD/Series) ──
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
        // Use whichever is more recent: added or last_modified
        final sa = ta > ma ? ta : ma;
        final sb = tb > mb ? tb : mb;
        return sb.compareTo(sa);
      });
      if (mounted) setState(() => _recentlyAdded = items.take(20).toList());
    } catch (_) {
      // Non-blocking: if it fails, just don't show the section
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

    // Build channel list for quick zapping in live mode
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

  void _showShortcutsHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Raccourcis clavier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
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
          child: Text(key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF4A90D9))),
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

  // ── Widgets helpers ──

  /// Clé de progression pour un item selon le mode courant.
  String? _progressKey(Map<String, dynamic> stream) {
    if (_mode == ContentMode.live) return null;
    return _mode == ContentMode.series
        ? stream['series_id']?.toString()
        : stream['stream_id']?.toString();
  }

  Widget _networkImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width, height: height, fit: fit,
      placeholder: (_, __) => Container(color: Colors.white10),
      errorWidget: (_, __, ___) => Container(
        color: Colors.white10,
        child: Icon(_mode == ContentMode.series ? Icons.movie : Icons.tv,
            color: Colors.white24, size: 24),
      ),
    );
  }

  Widget _listIcon(Map<String, dynamic> stream) {
    final iconUrl = _mode == ContentMode.series ? stream['cover'] : stream['stream_icon'];
    final fallback = Icon(_mode == ContentMode.series ? Icons.movie : Icons.tv, color: Colors.white38);
    if (iconUrl == null || iconUrl.toString().isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _networkImage(iconUrl.toString(), width: 40, height: 40),
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
                      size: 16, color: const Color(0xFF4A90D9)),
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
            fillColor: const Color(0xFF4A90D9),
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
            tooltip: 'Trier',
            onSelected: (v) { setState(() => _sortMode = v); _saveSortMode(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'default', child: Row(children: [
                Icon(_sortMode == 'default' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: const Color(0xFF4A90D9)),
                const SizedBox(width: 8), const Text('Ordre par défaut', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'alpha', child: Row(children: [
                Icon(_sortMode == 'alpha' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: const Color(0xFF4A90D9)),
                const SizedBox(width: 8), const Text('Alphabétique', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'number', child: Row(children: [
                Icon(_sortMode == 'number' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: const Color(0xFF4A90D9)),
                const SizedBox(width: 8), const Text('Par numéro', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'favFirst', child: Row(children: [
                Icon(_sortMode == 'favFirst' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: const Color(0xFF4A90D9)),
                const SizedBox(width: 8), const Text('Favoris en premier', style: TextStyle(fontSize: 13)),
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
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings, tooltip: 'Paramètres'),
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
              _buildContinueWatching(),
              _buildRecentlyAdded(),
              Expanded(child: Row(children: [
              // Sidebar catégories (redimensionnable)
              SizedBox(
                width: _sidebarWidth,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: () {
                    final modeCollections = _collections.where((c) =>
                        c['mode'] == null || c['mode'] == _mode.key).toList();
                    return _categories.length + 3 + modeCollections.length + (modeCollections.isNotEmpty ? 1 : 0);
                  }(),
                  itemBuilder: (_, i) {
                    final modeCollections = _collections.where((c) =>
                        c['mode'] == null || c['mode'] == _mode.key).toList();
                    if (i == 0) {
                      final sel = _selectedCategory == '__favorites__';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.star, size: 16,
                              color: sel ? Colors.amber : Colors.amber.withValues(alpha: 0.5)),
                          title: Text('Favoris', style: TextStyle(fontSize: 13,
                              color: sel ? Colors.white : Colors.white60,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          selected: sel,
                          selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => setState(() {
                            _selectedCategory = '__favorites__';
                            _streams = _favItems.where((e) => e['_mode'] == _mode.key).toList();
                          }),
                        ),
                      );
                    }
                    if (i == 1) {
                      final sel = _selectedCategory == '__watchlist__';
                      final wlModeItems = _wlItems.where((e) => e['_mode'] == _mode.key).toList();
                      final wlCount = wlModeItems.length;
                      final unwatchedCount = wlModeItems.where((e) {
                        final id = _mode == ContentMode.series ? e['series_id']?.toString() : e['stream_id']?.toString();
                        if (id == null) return true;
                        final p = _progress[id];
                        return p == null || p <= 0.95;
                      }).length;
                      final countLabel = wlCount > 0
                          ? (unwatchedCount < wlCount ? ' ($unwatchedCount/$wlCount)' : ' ($wlCount)')
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.bookmark, size: 16,
                                  color: sel ? Colors.tealAccent : Colors.tealAccent.withValues(alpha: 0.5)),
                              if (unwatchedCount > 0)
                                Positioned(top: -4, right: -6,
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4A90D9),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text('À regarder$countLabel', style: TextStyle(fontSize: 13,
                              color: sel ? Colors.white : Colors.white60,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          selected: sel,
                          selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => setState(() {
                            _selectedCategory = '__watchlist__';
                            _streams = _wlItems.where((e) => e['_mode'] == _mode.key).toList();
                          }),
                        ),
                      );
                    }
                    if (i == 2) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.history, size: 16,
                              color: Colors.white54),
                          title: Text('Historique', style: TextStyle(fontSize: 13,
                              color: Colors.white60)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => Navigator.push(context,
                              fadeRoute(const HistoryScreen()))
                              .then((_) => _refreshProgress()),
                        ),
                      );
                    }
                    // Collections section (filtered by mode)
                    final colHeaderIdx = 3;
                    final colStartIdx = modeCollections.isNotEmpty ? colHeaderIdx + 1 : colHeaderIdx;
                    final colEndIdx = colStartIdx + modeCollections.length;
                    final catStartIdx = colEndIdx;

                    if (modeCollections.isNotEmpty && i == colHeaderIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2, left: 8, right: 4),
                        child: Row(children: [
                          const Text('COLLECTIONS', style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 0.8)),
                          const Spacer(),
                          SizedBox(
                            width: 24, height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const Icon(Icons.add, color: Colors.white38),
                              tooltip: 'Nouvelle collection',
                              onPressed: _createCollection,
                            ),
                          ),
                        ]),
                      );
                    }

                    if (i >= colStartIdx && i < colEndIdx) {
                      final col = modeCollections[i - colStartIdx];
                      final colId = '__col_${col['id']}__';
                      final sel = _selectedCategory == colId;
                      final items = (col['items'] as List?) ?? [];
                      final count = col['mode'] != null
                          ? items.length
                          : items.where((e) => e['mode'] == _mode.key).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.folder_outlined, size: 16,
                              color: sel ? const Color(0xFF4A90D9) : Colors.white38),
                          title: Text('${col['name']} ($count)', style: TextStyle(fontSize: 13,
                              color: sel ? Colors.white : Colors.white60,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          selected: sel,
                          selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            final colItems = (col['items'] as List)
                                .where((e) => e['mode'] == _mode.key)
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                            setState(() {
                              _selectedCategory = colId;
                              _streams = colItems;
                            });
                          },
                          trailing: SizedBox(
                            width: 24, height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white24),
                              tooltip: 'Supprimer',
                              onPressed: () async {
                                await CollectionsService.deleteCollection(col['id'] as String);
                                await _loadCollections();
                                if (_selectedCategory == colId) {
                                  setState(() { _selectedCategory = null; _streams = []; });
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }

                    final cat = _categories[i - catStartIdx];
                    final id  = cat['category_id'].toString();
                    final sel = _selectedCategory == id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        dense: true,
                        title: Text(cat['category_name'] ?? '',
                            style: TextStyle(fontSize: 13,
                                color: sel ? Colors.white : Colors.white60,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                            overflow: TextOverflow.ellipsis),
                        selected: sel,
                        selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () => _loadStreams(id),
                      ),
                    );
                  },
                ),
              ),
              // Handle de redimensionnement
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    setState(() => _sidebarWidth = (_sidebarWidth + d.delta.dx).clamp(_sidebarMin, _sidebarMax));
                  },
                  onHorizontalDragEnd: (_) => _saveSidebarWidth(),
                  child: Container(
                    width: 5,
                    color: Colors.transparent,
                    child: const Center(child: VerticalDivider(width: 1, color: Colors.white12)),
                  ),
                ),
              ),
              // Zone streams
              Expanded(
                child: _selectedCategory == null
                    ? const Center(child: Text('Sélectionne une catégorie',

                        style: TextStyle(color: Colors.white38, fontSize: 16)))
                    : _loadingStreams
                    ? SkeletonList(count: showGrid ? 16 : 12, isGrid: showGrid)
                    : Column(children: [
                        // Barre de sélection (mode sélection) ou recherche
                        if (_selectionMode)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                            child: Row(children: [
                              Text('${_selectedItems.length} sélectionné${_selectedItems.length > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.select_all, size: 16),
                                label: const Text('Tout', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setState(() {
                                    if (_selectedItems.length == _streams.length) {
                                      _selectedItems = {};
                                    } else {
                                      _selectedItems = _streams.cast<Map<String, dynamic>>()
                                          .map((s) => _itemSelectionKey(s)).toSet();
                                    }
                                  });
                                },
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFF4A90D9)),
                                label: const Text('Créer collection', style: TextStyle(fontSize: 12, color: Color(0xFF4A90D9))),
                                onPressed: _selectedItems.isEmpty ? null : _createCollectionFromSelected,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                                tooltip: 'Annuler la sélection',
                                onPressed: _exitSelectionMode,
                              ),
                            ]),
                          )
                        else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(children: [
                            Expanded(child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Rechercher...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                        onPressed: () => setState(() { _searchQuery = ''; _searchCtrl.clear(); }),
                                      )
                                    : null,
                                isDense: true, filled: true, fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                            )),
                            if (_selectedCategory == '__favorites__' || _selectedCategory == '__watchlist__')
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Tooltip(
                                  message: 'Sélectionner pour créer une collection',
                                  child: IconButton(
                                    icon: const Icon(Icons.checklist, size: 20, color: Color(0xFF4A90D9)),
                                    onPressed: _streams.isEmpty ? null : _enterSelectionMode,
                                  ),
                                ),
                              ),
                          ]),
                        ),
                        Expanded(child: Builder(builder: (ctx) {
                          final filtered = _searchQuery.isEmpty
                              ? _sortedStreams
                              : _sortedStreams.where((s) => (s['name'] ?? '')
                                  .toString().toLowerCase().contains(_searchQuery)).toList();

                          if (showGrid) return _buildGrid(filtered);
                          return _buildList(filtered);
                        })),
                      ]),
              ),
            ])),  // close Row + Expanded
          ]),  // close Column
    ),  // close Scaffold
    );  // close Focus
  }

  Widget _buildContinueWatching() {
    if (_continueItems.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text('Continuer à regarder',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.white54, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _continueItems.length,
          itemBuilder: (_, i) {
            final item  = _continueItems[i];
            final ratio = item['_ratio'] as double;
            final cover = item['cover'] as String? ?? '';
            final name  = item['name']  as String? ?? '';
            final url   = item['url']   as String? ?? '';
            final key   = item['_id']   as String;
            return GestureDetector(
              onTap: () => Navigator.push(context, slideRoute(
                PlayerScreen(url: url, title: name, resumeKey: key),
              )).then((_) => _refreshProgress()),
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
                    ]),
                  )),
                  const SizedBox(height: 3),
                  Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
      const Divider(color: Colors.white12, height: 1),
    ]);
  }

  // ── Récemment ajoutés ──
  Widget _buildRecentlyAdded() {
    if (_recentlyAdded.isEmpty || _mode == ContentMode.live) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text('Récemment ajoutés',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.white54, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _recentlyAdded.length,
          itemBuilder: (_, i) {
            final item  = _recentlyAdded[i];
            final cover = _mode == ContentMode.series
                ? (item['cover'] as String? ?? '')
                : (item['stream_icon'] as String? ?? '');
            final name  = item['name'] as String? ?? '';
            return GestureDetector(
              onTap: () => _playStream(item),
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: cover.isNotEmpty
                        ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.white10),
                            errorWidget: (_, __, ___) => Container(color: Colors.white10,
                                child: const Icon(Icons.fiber_new, color: Colors.white24)))
                        : Container(color: Colors.white10,
                            child: const Icon(Icons.fiber_new, color: Colors.white24)),
                  )),
                  const SizedBox(height: 3),
                  Text(name, style: const TextStyle(fontSize: 10, color: Colors.white60),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
      const Divider(color: Colors.white12, height: 1),
    ]);
  }

  // ── Mode hors-ligne ──
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
            const Text('Continuer à regarder',
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
                    message: 'Connexion requise',
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
            const Text('Favoris',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            ...(_favItems.take(20).map((item) {
              final name = item['name'] as String? ?? '';
              final cover = item['cover']?.toString() ?? item['stream_icon']?.toString() ?? '';
              return Tooltip(
                message: 'Connexion requise',
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
                Text('Aucune donnée en cache disponible',
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
              ]),
            )),
        ]),
      )),
    ]);
  }

  // ── Right-click info dialog ──
  void _showStreamInfoDialog(Map<String, dynamic> s) {
    final name = s['name'] ?? 'Sans titre';
    final mode = _mode;
    final modeLabels = {ContentMode.live: 'Live', ContentMode.vod: 'VOD', ContentMode.series: 'Série'};
    final modeColors = {ContentMode.live: Colors.redAccent, ContentMode.vod: Colors.amber, ContentMode.series: Colors.tealAccent};

    final infoParts = <String>[];
    if (s['category_name'] != null) infoParts.add('Catégorie : ${s['category_name']}');
    if (s['rating'] != null && s['rating'].toString().isNotEmpty && s['rating'].toString() != '0') {
      infoParts.add('Note : ${s['rating']}');
    }
    if (mode == ContentMode.series && s['num_seasons'] != null) {
      infoParts.add('Saisons : ${s['num_seasons']}');
    }
    if (mode == ContentMode.vod && s['stream_type'] != null) {
      infoParts.add('Type : ${s['stream_type']}');
    }
    final plot = s['plot'] ?? s['description'];
    if (plot != null && plot.toString().isNotEmpty) {
      infoParts.add(plot.toString());
    }

    // For live channels, fetch short EPG
    if (mode == ContentMode.live) {
      final streamId = s['stream_id']?.toString() ?? '';
      // Show dialog with loading, then update
      final epgNotifier = ValueNotifier<String?>(
        XtreamApi.getCachedEpgNow(streamId) ?? '...',
      );
      if (streamId.isNotEmpty && XtreamApi.getCachedEpgNow(streamId) == null) {
        XtreamApi.getShortEpg(streamId, limit: 2).then((data) {
          final prog = XtreamApi.getCachedEpgNow(streamId);
          epgNotifier.value = prog ?? 'Aucun programme';
        }).catchError((_) {
          epgNotifier.value = 'EPG indisponible';
        });
      }
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: Text(name, style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (modeColors[mode] ?? Colors.grey).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4)),
            child: Text(modeLabels[mode] ?? mode.label,
                style: TextStyle(fontSize: 11, color: modeColors[mode] ?? Colors.grey)),
          ),
          if (infoParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...infoParts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            )),
          ],
          const SizedBox(height: 8),
          const Text('Programme en cours :', style: TextStyle(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 4),
          ValueListenableBuilder<String?>(
            valueListenable: epgNotifier,
            builder: (_, val, __) => Text(val ?? 'Aucun programme',
                style: const TextStyle(fontSize: 13, color: Colors.tealAccent)),
          ),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddToCollectionPicker(s);
            },
            icon: const Icon(Icons.folder_outlined, size: 16),
            label: const Text('Collection'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ));
    } else {
      // VOD / Series
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: Text(name, style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (modeColors[mode] ?? Colors.grey).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4)),
            child: Text(modeLabels[mode] ?? mode.label,
                style: TextStyle(fontSize: 11, color: modeColors[mode] ?? Colors.grey)),
          ),
          if (infoParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...infoParts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            )),
          ],
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddToCollectionPicker(s);
            },
            icon: const Icon(Icons.folder_outlined, size: 16),
            label: const Text('Collection'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ));
    }
  }

  // ── Vue liste ──
  Widget _buildList(List<dynamic> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s   = items[i] as Map<String, dynamic>;
        final pKey = _progressKey(s);
        final prog = pKey != null ? _progress[pKey] : null;
        // For live channels, show cached current program as subtitle
        String? liveEpgTitle;
        if (_mode == ContentMode.live) {
          final sid = s['stream_id']?.toString() ?? '';
          if (sid.isNotEmpty) liveEpgTitle = XtreamApi.getCachedEpgNow(sid);
        }
        Widget? subtitle;
        if (prog != null || liveEpgTitle != null) {
          subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (liveEpgTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(liveEpgTitle, style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              if (prog != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: prog,
                    backgroundColor: Colors.white12,
                    color: Colors.amber,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        }
        final selKey = _itemSelectionKey(s);
        final isSelected = _selectionMode && _selectedItems.contains(selKey);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onSecondaryTapUp: _selectionMode ? null : (_) => _showStreamInfoDialog(s),
            child: ListTile(
              leading: _selectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => setState(() {
                        if (isSelected) _selectedItems.remove(selKey);
                        else _selectedItems.add(selKey);
                      }),
                      activeColor: const Color(0xFF4A90D9),
                    )
                  : _listIcon(s),
              title: Text(s['name'] ?? 'Sans titre',
                  style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: subtitle,
              trailing: _selectionMode ? null : Row(mainAxisSize: MainAxisSize.min, children: [
                if (_activeCollectionId != null) IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  tooltip: 'Retirer de la collection',
                  onPressed: () => _removeFromCollection(s),
                ),
                if (_mode != ContentMode.live) IconButton(
                  icon: Icon(
                    _wlKeys.contains(_favKey(_mode.key, s)) ? Icons.bookmark : Icons.bookmark_border,
                    color: _wlKeys.contains(_favKey(_mode.key, s)) ? Colors.tealAccent : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => _toggleWatchlist(s),
                  tooltip: 'À regarder plus tard',
                ),
                IconButton(
                  icon: Icon(
                    _favKeys.contains(_favKey(_mode.key, s)) ? Icons.star : Icons.star_border,
                    color: _favKeys.contains(_favKey(_mode.key, s)) ? Colors.amber : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => _toggleFavorite(s),
                ),
              ]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
              selectedTileColor: const Color(0xFF4A90D9).withValues(alpha: 0.1),
              selected: isSelected,
              onTap: _selectionMode
                  ? () => setState(() {
                      if (isSelected) _selectedItems.remove(selKey);
                      else _selectedItems.add(selKey);
                    })
                  : () => _playStream(s),
            ),
          ),
        );
      },
    );
  }

  // ── Vue grille ──
  Widget _buildGrid(List<dynamic> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.58, // ratio cover 2:3 + titre
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s    = items[i] as Map<String, dynamic>;
        final pKey  = _progressKey(s);
        final prog  = pKey != null ? _progress[pKey] : null;
        final cover = _mode == ContentMode.series ? s['cover'] : s['stream_icon'];
        final isFav = _favKeys.contains(_favKey(_mode.key, s));
        final selKey = _itemSelectionKey(s);
        final isSelected = _selectionMode && _selectedItems.contains(selKey);

        return GestureDetector(
          onTap: _selectionMode
              ? () => setState(() {
                  if (isSelected) _selectedItems.remove(selKey);
                  else _selectedItems.add(selKey);
                })
              : () => _playStream(s),
          onSecondaryTapUp: _selectionMode ? null : (_) => _showStreamInfoDialog(s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(fit: StackFit.expand, children: [
                  if (cover != null && cover.toString().isNotEmpty)
                    _networkImage(cover.toString())
                  else
                    Container(color: Colors.white10,
                        child: Icon(_mode == ContentMode.series ? Icons.movie : Icons.tv,
                            color: Colors.white24, size: 32)),
                  // Barre de progression en bas de la cover
                  if (prog != null)
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: LinearProgressIndicator(
                        value: prog,
                        backgroundColor: Colors.black45,
                        color: Colors.amber,
                        minHeight: 4,
                      ),
                    ),
                  // Retirer de la collection
                  if (!_selectionMode && _activeCollectionId != null)
                    Positioned(bottom: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => _removeFromCollection(s),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 14),
                        ),
                      ),
                    ),
                  // Bookmark watchlist
                  if (_mode != ContentMode.live)
                    Positioned(top: 4, left: 4,
                      child: GestureDetector(
                        onTap: () => _toggleWatchlist(s),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(_wlKeys.contains(_favKey(_mode.key, s)) ? Icons.bookmark : Icons.bookmark_border,
                              color: _wlKeys.contains(_favKey(_mode.key, s)) ? Colors.tealAccent : Colors.white54, size: 14),
                        ),
                      ),
                    ),
                  // Étoile favori
                  if (!_selectionMode)
                  Positioned(top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(s),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(isFav ? Icons.star : Icons.star_border,
                            color: isFav ? Colors.amber : Colors.white54, size: 14),
                      ),
                    ),
                  ),
                  // Checkbox sélection
                  if (_selectionMode)
                  Positioned(top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4A90D9) : Colors.black54,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(isSelected ? Icons.check : Icons.circle_outlined,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  // Bordure de sélection
                  if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4A90D9), width: 2),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            Text(s['name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        );
      },
    );
  }
}

