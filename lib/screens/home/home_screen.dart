import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/preferences_repository.dart';
import '../../core/design_tokens.dart';
import '../../core/theme_colors.dart';
import '../../widgets/skeleton_list.dart';
import '../channel_detail_screen.dart';
import 'accueil_view.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/app_config.dart';
import '../../models/collection_data.dart';
import '../../models/favorite_item.dart';
import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../models/vod_item.dart';
import '../../models/series_item.dart';
import '../../repositories/content_repository.dart';
import '../../utils/api_error_localizer.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/routes.dart';
import '../../utils/content_key.dart';
import '../../utils/stream_helpers.dart';
import '../../models/content_mode.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/watch_progress_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../utils/feature_access.dart';
import '../../widgets/premium_gate.dart';
import '../../providers/paginated_streams_provider.dart';
import '../../providers/parental_provider.dart';
import '../../services/connectivity_service.dart';
import '../settings_screen.dart';
import '../series_detail_screen.dart';
import '../player/player_screen.dart';
import '../history_screen.dart';
import '../epg/epg_grid_screen.dart';
import '../favorites_screen.dart';
import '../search_screen.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/stream_list.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/catchup_row.dart';
import 'widgets/collection_dialogs.dart';
import 'widgets/shortcuts_dialog.dart';
import 'widgets/offline_content.dart';
import '../vod/vod_detail_screen.dart';
import '../../providers/tmdb_provider.dart';
import '../../services/tmdb_service.dart';
import 'widgets/ambient_wallpaper.dart';
import 'widgets/catalog_sort_chips.dart';
import 'widgets/focused_item_preview.dart';
import 'widgets/home_hero.dart';
import 'widgets/inline_search_field.dart';
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
  /// Ambient wallpaper target for the Films / Séries split view —
  /// driven by the hero's rotation and (optionally) by hover on the
  /// CW / Recently Added rows. Mirror of AccueilView's pattern, so
  /// the whole app reads as one immersive surface.
  dynamic _splitWallpaperItem;
  dynamic _splitHoveredItem;

  /// Currently hovered tile in the main grid — drives the bottom-of-
  /// grid `FocusedItemPreview` panel (Apple TV+ focus-engine preview
  /// on desktop). Distinct from `_splitHoveredItem` (which only
  /// covers shelf cards in the header).
  dynamic _gridHoveredItem;

  /// Whether the user is on the cross-mode Accueil. Drives the
  /// AppBar segment toggle, the sidebar visibility, and which body is
  /// rendered. Defaults to [HomeSegment.home] except when a demo
  /// override forces a specific content mode (TestFlight harness).
  HomeSegment _segment = kDemoMode && kDemoScreen == 'vod'
      ? HomeSegment.vod
      : (kDemoMode && kDemoScreen == 'series'
          ? HomeSegment.series
          : HomeSegment.home);

  /// Last-visited content mode. Independent of [_segment] so the user
  /// can flip Home → Live → Home and the second Home → Live brings
  /// them back to Live, not to the previously-selected category from
  /// before they detoured through Home.
  ContentMode _mode = kDemoMode && kDemoScreen == 'vod'
      ? ContentMode.vod
      : (kDemoMode && kDemoScreen == 'series' ? ContentMode.series : ContentMode.live);

  // (Removed: connectivity offline→online tracking now lives in
  // `ref.listenManual(connectivityProvider, ...)` set up in
  // initState, not in build().)

  // Recently added (VOD/Series) — populated per-mode for the legacy
  // grid header (Films, Séries). [_accueilFeatured] below is the
  // cross-mode equivalent for the Accueil hero + recently-added.
  List<dynamic> _recentlyAdded = [];

  // Cross-mode "Featured" list — VOD + Series merged, sorted by
  // recency. Loaded once at init so the Accueil renders fast the
  // first time it's selected.
  List<dynamic> _accueilFeatured = const <dynamic>[];

  // Catch-up programs (Live mode only)
  List<CatchupProgram> _catchupPrograms = [];

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Grid view (VOD + Series only)
  // Default to grid view (tiles) for every mode including Live. Users can
  // toggle back to list via the AppBar icon and the preference is persisted.
  bool _gridView = true;

  // Sort mode
  String _sortMode = 'default';

  // Selection mode
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

  // Sidebar width (resizable)
  double _sidebarWidth = 250;
  static const double _sidebarMin = 150;
  static const double _sidebarMax = 400;

  // Drawer is opened via `Scaffold.of(ctx).openDrawer()` through a
  // `Builder` (see `leadingMenuButton` below). Storing a
  // `GlobalKey<ScaffoldState>` here would re-introduce the
  // GlobalKey-reparenting class of bugs (the
  // `_InactiveElements.remove → _elements.contains` assertion fires
  // when a build that targets a route mid-pop triggers a retake).

  /// Scroll offset of the main grid/list — drives the app-bar backdrop fade
  /// so it becomes opaque as soon as tiles start scrolling behind it.
  final ValueNotifier<double> _mainScrollOffset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _init();
    _loadSidebarWidth();
    _loadGridView();
    _loadSortMode();
    // Connectivity offline→online: snackbar + retry. Previously
    // hooked inside `build()` (mutating `_prevConnectivity` mid-
    // render + scheduling a post-frame setState). Moved here so
    // build is side-effect free.
    ref.listenManual<AsyncValue<ConnectivityStatus>>(connectivityProvider,
        (prev, next) {
      final p = prev?.valueOrNull;
      final n = next.valueOrNull;
      if (p == ConnectivityStatus.offline && n == ConnectivityStatus.online) {
        if (mounted) {
          showAppSnackBar(
              context, AppLocalizations.of(context)!.connexionRetablie);
          _retryConnection();
        }
      }
    });
  }

  @override
  void dispose() {
    _mainScrollOffset.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
    if (!checkPremiumAccess(context, ref, Feature.collections)) return;
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
    if (!checkPremiumAccess(context, ref, Feature.collections)) return;
    final items = _streams
        .where((s) => _selectedItems.contains(_itemSelectionKey(s)))
        .toList();
    if (items.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    final name = await showCreateCollectionFromSelectedDialog(context, itemCount: items.length);
    if (name == null || name.isEmpty) return;
    final col = await ref.read(collectionsProvider.notifier).create(name, mode: _mode.key);
    for (final s in items) {
      final key = _favKey(_mode.key, s);
      final itemName = getStreamName(s);
      final cover = getStreamIcon(s);
      final item = FavoriteItem(key: key, name: itemName.isEmpty ? l10n.sansTitre : itemName, cover: cover, mode: _mode.key);
      await ref.read(collectionsProvider.notifier).addItem(col.id, item);
    }
    _exitSelectionMode();
    if (mounted) {
      showAppSnackBar(context, l10n.collectionCreeAvec(name, items.length));
    }
  }

  // Memoization of `_sortedStreams`. `build()` is called on every
  // provider change (and there are 8 watched) — sorting a 10k+
  // stream list on each rebuild caused visible jank on iPad.
  //
  // Cache key encodes the inputs that actually affect the result:
  //   * source list identity (any `setState(() => _streams = ...)`
  //     binds a new instance, so identity check catches it)
  //   * sort mode
  //   * for fav-dependent modes, the favourites keys length (cheap
  //     proxy that bumps on every fav toggle)
  //   * for progress-dependent modes, the progress map length
  //
  // For 'default' / 'alpha' / 'number' / 'recent' the cache is
  // perfectly stable; for 'favFirst' / 'unwatched' / 'inProgress'
  // it's stable between fav/progress changes (still rebuilds when
  // the user toggles a favourite — which is what we want).
  List<dynamic>? _sortCache;
  Object? _sortCacheSource;
  String? _sortCacheKey;

  List<dynamic> get _sortedStreams {
    if (_sortMode == 'default') return _streams;

    // Build cheap cache signature.
    int favSig = 0;
    int progSig = 0;
    if (_sortMode == 'favFirst') {
      favSig = ref.read(favoritesProvider).keys.length;
    } else if (_sortMode == 'unwatched' || _sortMode == 'inProgress') {
      progSig = (ref.read(watchProgressProvider).valueOrNull ?? const {}).length;
    }
    final key = '$_sortMode|$favSig|$progSig';
    if (identical(_sortCacheSource, _streams) &&
        _sortCacheKey == key &&
        _sortCache != null) {
      return _sortCache!;
    }

    final list = List<dynamic>.from(_streams);

    int recencyKey(dynamic it) {
      final added = (it is VodItem
              ? it.added
              : it is SeriesItem
                  ? it.added
                  : null)?.toString() ??
          '0';
      final lastMod = (it is VodItem
              ? it.lastModified
              : it is SeriesItem
                  ? it.lastModified
                  : null)?.toString() ??
          '0';
      final ta = int.tryParse(added) ?? 0;
      final tm = int.tryParse(lastMod) ?? 0;
      return ta > tm ? ta : tm;
    }

    String contentKeyForSort(dynamic it) {
      // Match the keys persisted in watch_progress: `vod_<id>` for
      // films, `series_<id>` for series. Live channels and Map
      // entries fall back to a bare id (no progress will match,
      // which is fine — those modes don't use unwatched / inProgress).
      if (it is VodItem) return ContentKey.make(ContentKey.movie, it.id);
      if (it is SeriesItem) {
        return ContentKey.make(ContentKey.series, it.id);
      }
      return getStreamId(it);
    }

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
      case 'recent':
        list.sort((a, b) => recencyKey(b).compareTo(recencyKey(a)));
        break;
      case 'unwatched':
        // Keep items with no progress or just-touched progress
        // (< 0.5 %). Stable sort by name for deterministic ordering.
        final progress = ref.read(watchProgressProvider).valueOrNull ??
            const <String, double>{};
        final filtered = list.where((it) {
          final r = progress[contentKeyForSort(it)];
          return r == null || r < 0.005;
        }).toList();
        filtered.sort((a, b) => getStreamName(a).toLowerCase()
            .compareTo(getStreamName(b).toLowerCase()));
        _sortCacheSource = _streams;
        _sortCacheKey = key;
        _sortCache = filtered;
        return filtered;
      case 'inProgress':
        // Items currently being watched (0.5 % – 95 %). Sort most-
        // recently-watched first via the saved ratio as a proxy
        // (closer to 1 = more time invested).
        final progress = ref.read(watchProgressProvider).valueOrNull ??
            const <String, double>{};
        final filtered = list.where((it) {
          final r = progress[contentKeyForSort(it)];
          return r != null && r > 0.005 && r < 0.95;
        }).toList();
        filtered.sort((a, b) {
          final ra = progress[contentKeyForSort(a)] ?? 0;
          final rb = progress[contentKeyForSort(b)] ?? 0;
          return rb.compareTo(ra);
        });
        _sortCacheSource = _streams;
        _sortCacheKey = key;
        _sortCache = filtered;
        return filtered;
    }
    _sortCacheSource = _streams;
    _sortCacheKey = key;
    _sortCache = list;
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
  //
  // Favourite keys are now bare item ids (no prefix), aligning with the
  // tvOS native app — both platforms write to `user_favorites.item_key`
  // with the same string. The `mode` discriminator lives in the JSON
  // payload (`item_json.mode`), so a movie streamId and a series id
  // that happen to share digits are still distinguishable.
  String _favKey(String mode, dynamic s) {
    if (s is Map<String, dynamic>) {
      return (mode == 'series' ? s['series_id'] : s['stream_id'])?.toString() ?? '';
    }
    return getStreamId(s);
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
        // Kick off the cross-mode load in parallel with the per-mode
        // categories so the Accueil hero is ready by the time the
        // first frame settles (otherwise the hero stays empty until
        // the user explicitly re-enters Accueil — see initial bug
        // report on PR 8).
        if (_accueilFeatured.isEmpty) {
          // ignore: unawaited_futures
          _loadAccueilFeatured();
        }
        await _loadCategories();
      } else {
        setState(() { _error = AppLocalizations.of(context)!.authEchouee; _loading = false; });
      }
    } catch (e, st) {
      AppLogger.error(LogModule.api, 'init failed', error: e, stackTrace: st);
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
      // Fire-and-forget the cross-mode load so the Accueil hero is
      // ready by the time the user lands on it. Cheap and runs in
      // parallel with the legacy per-mode loaders above.
      if (_accueilFeatured.isEmpty) _loadAccueilFeatured();
      // Catch-up also feeds Accueil now — make sure it's loaded even
      // when the user starts in a non-live segment.
      if (_segment == HomeSegment.home && _catchupPrograms.isEmpty) {
        _loadCatchupPrograms();
      }
      // Auto-select the first available category so the grid is never
      // empty on entry. Mirrors the tvOS pattern — landing on Live /
      // Films / Séries with a "Sélectionne une catégorie" placeholder
      // is a worse first impression than just showing the first list
      // (the user can still navigate to another via the sidebar). We
      // skip when:
      //   * a category is already selected (e.g. coming back from a
      //     route push that preserved state),
      //   * we're on the Home segment (Accueil owns its own surface),
      //   * the categories list is empty (nothing to pick).
      //
      // Parental controls: skip categories blocked by the active PIN
      // gate so a locked profile can't see a blocked list flash by.
      if (_selectedCategory == null &&
          _segment != HomeSegment.home &&
          _categories.isNotEmpty) {
        final parental = ref.read(parentalProvider);
        final blocked = parental.isEnabled && !parental.isUnlocked
            ? parental.blockedCategoryIds
            : const <String>{};
        final firstVisible = _categories.firstWhere(
          (c) => !blocked.contains(c.categoryId),
          orElse: () => _categories.first,
        );
        _loadStreams(firstVisible.categoryId);
      }
    } catch (e, st) {
      AppLogger.error(LogModule.api, 'loadCategories failed mode=${_mode.key}', error: e, stackTrace: st);
      setState(() { _error = localizeApiError(_repo.errorKey(e), AppLocalizations.of(context)!); _loading = false; });
    }
  }

  /// Cross-mode "Featured" loader: VOD + Series merged and sorted by
  /// recency. Feeds the Accueil hero rotation + Recently Added row.
  /// Independent of [_loadRecentlyAdded] (which is per-mode and feeds
  /// the legacy split-view headers).
  Future<void> _loadAccueilFeatured() async {
    AppLogger.debug(LogModule.ui, 'Loading Accueil featured items…');
    try {
      final results = await Future.wait<List<dynamic>>(<Future<List<dynamic>>>[
        _repo.getVodStreams().then((v) => v.cast<dynamic>()),
        _repo.getSeries().then((s) => s.cast<dynamic>()),
      ]);
      final vodCount = results[0].length;
      final seriesCount = results[1].length;
      final all = <dynamic>[...results[0], ...results[1]];
      int recencyKey(dynamic it) {
        final added = (it is VodItem
                ? it.added
                : it is SeriesItem
                    ? it.added
                    : null)?.toString() ??
            '0';
        final lastMod = (it is VodItem
                ? it.lastModified
                : it is SeriesItem
                    ? it.lastModified
                    : null)?.toString() ??
            '0';
        final ta = int.tryParse(added) ?? 0;
        final tm = int.tryParse(lastMod) ?? 0;
        return ta > tm ? ta : tm;
      }
      all.sort((a, b) => recencyKey(b).compareTo(recencyKey(a)));
      if (!mounted) return;
      setState(() => _accueilFeatured = all.take(30).toList());
      AppLogger.debug(LogModule.ui,
          'Accueil featured loaded: ${_accueilFeatured.length}/${all.length} items (vod=$vodCount, series=$seriesCount)');
    } catch (e, st) {
      AppLogger.warning(LogModule.ui,
          'Failed to load Accueil featured items', error: e, stackTrace: st);
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
  /// Runs for both the legacy Live split-view header AND the
  /// Accueil cross-mode home — the user can land on catch-up content
  /// from either surface.
  Future<void> _loadCatchupPrograms() async {
    final wantsCatchup =
        _mode == ContentMode.live || _segment == HomeSegment.home;
    if (!wantsCatchup) {
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
        } catch (e) {
          AppLogger.debug('epg', 'Catch-up EPG skipped for channel: $e');
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
    } catch (e, st) {
      AppLogger.error(LogModule.api, 'loadStreams failed mode=${_mode.key} cat=$categoryId', error: e, stackTrace: st);
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
  /// Fires the TMDB lookup in the background so the cache is warm when the
  /// detail screen mounts. Silently no-ops on Live streams and when TMDB is
  /// disabled.
  void _prefetchTmdb(dynamic stream) {
    final cfg = ref.read(tmdbConfigProvider);
    if (!cfg.isActive) return;
    final name = getStreamName(stream);
    if (name.isEmpty) return;
    TmdbKind? kind;
    if (stream is VodItem || _mode == ContentMode.vod) kind = TmdbKind.movie;
    if (stream is SeriesItem || _mode == ContentMode.series) kind = TmdbKind.tv;
    if (kind == null) return;
    // ref.read on a FutureProvider kicks off the fetch and writes to cache.
    ref.read(tmdbLookupProvider(TmdbLookup(rawTitle: name, kind: kind)));
  }

  /// Hover handler for grid tiles — feeds the bottom-of-grid
  /// `FocusedItemPreview`. Same route-current safety as the shelf
  /// hover handlers to dodge the framework's `_elements.contains`
  /// assertion when a tap-then-navigate races the MouseRegion exit.
  void _onGridItemHover(dynamic item, bool isHovered) {
    Future<void>.microtask(() {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (isHovered) {
        if (identical(_gridHoveredItem, item)) return;
        setState(() => _gridHoveredItem = item);
      } else {
        if (!identical(_gridHoveredItem, item)) return;
        setState(() => _gridHoveredItem = null);
      }
    });
  }

  /// Hover handler for the Films / Séries split-view shelves (CW
  /// and Recently Added). Mirror of AccueilView's pattern.
  void _onSplitItemHover(dynamic source, bool isHovered) {
    Future<void>.microtask(() {
      if (!mounted) return;
      // Same route-current guard as AccueilView — protects against
      // `_elements.contains(element)` assertion when the microtask
      // fires while we're sitting behind a detail / player screen.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (isHovered) {
        final target = toWallpaperTarget(source);
        if (target == null) return;
        if (identical(_splitHoveredItem, target)) return;
        setState(() => _splitHoveredItem = target);
      } else {
        if (_splitHoveredItem == null) return;
        setState(() => _splitHoveredItem = null);
      }
    });
  }

  /// Open a favourite from the Accueil shelves. Dispatches by
  /// [FavoriteItem.mode] to the right destination — live channels
  /// open the player straight away, films/series push their detail.
  void _openFavorite(FavoriteItem fav) {
    switch (fav.mode) {
      case 'live':
        final id = fav.streamId;
        if (id == null || id.isEmpty) return;
        final url = _repo.getLiveStreamUrl(id);
        final contentKey = ContentKey.make(ContentKey.live, id);
        ref.read(watchProgressActionsProvider).saveHistory(
              contentKey,
              fav.name,
              fav.cover,
              url,
              'live',
            );
        Navigator.push(
          context,
          slideRoute(PlayerScreen(
            url: url,
            title: fav.name,
            streamId: id,
          )),
        ).then((_) => _refreshProgress());
        break;
      case 'series':
        final sid = fav.seriesId ?? fav.streamId ?? fav.key;
        Navigator.push(
          context,
          slideRoute(SeriesDetailScreen(
            seriesId: sid,
            title: fav.name,
            cover: fav.cover,
            rating: fav.rating,
          )),
        ).then((_) => _refreshProgress());
        break;
      case 'vod':
      default:
        final vod = VodItem.fromJson(<String, dynamic>{
          'stream_id': fav.streamId ?? fav.key,
          'name': fav.name,
          'cover': fav.cover,
          'stream_icon': fav.streamIcon ?? fav.cover,
          'category_id': fav.categoryId,
          'container_extension': fav.containerExtension ?? 'mp4',
          'rating': fav.rating,
        });
        Navigator.push(
          context,
          slideRoute(VodDetailScreen(vod: vod)),
        ).then((_) => _refreshProgress());
        break;
    }
  }

  /// Open a Catch-up program from Accueil (mirrors the inline handler
  /// the Live header previously used).
  void _openCatchupProgram(CatchupProgram prog) {
    if (!checkPremiumAccess(context, ref, Feature.catchupReplay)) return;
    final url = prog.serverLocalStart.isNotEmpty
        ? _repo.getTimeshiftUrlFromLocal(
            prog.streamId, prog.serverLocalStart, prog.durationMin)
        : _repo.getTimeshiftUrl(
            prog.streamId, prog.startUtc, prog.durationMin);
    Navigator.push(
      context,
      slideRoute(PlayerScreen(
        url: url,
        title:
            '${prog.title} (${AppLocalizations.of(context)!.replay})',
        streamId: prog.streamId,
        isCatchup: true,
      )),
    );
  }

  /// Type-based router for Accueil items. Unlike [_playStream] (which
  /// keys off [_mode]), Accueil mixes VOD + Series + (later) live
  /// channels — so we dispatch on the runtime type and reuse the
  /// existing detail-screen pushes.
  void _openItemByType(dynamic item) {
    if (item is SeriesItem) {
      final saved = _mode;
      _mode = ContentMode.series;
      _playStream(item);
      _mode = saved;
      return;
    }
    if (item is VodItem) {
      final saved = _mode;
      _mode = ContentMode.vod;
      _playStream(item);
      _mode = saved;
      return;
    }
    // Fallback — channels or raw maps go through the regular path.
    _playStream(item);
  }

  void _playStream(dynamic stream) {
    final name = getStreamName(stream);
    final displayName = name.isEmpty ? AppLocalizations.of(context)!.sansTitre : name;
    AppLogger.breadcrumb('player', 'Stream play requested', data: {'title': displayName, 'mode': _mode.key});

    // Warm the TMDB cache the moment the user taps a tile. By the time the
    // slideRoute animation finishes (~300 ms) the synopsis + backdrop are
    // usually already resolved, so the detail screen renders with the final
    // content instead of flashing the old / empty state for a second.
    _prefetchTmdb(stream);

    if (_mode == ContentMode.series) {
      final seriesId = stream is SeriesItem ? stream.seriesId.toString() : (stream as Map<String, dynamic>)['series_id'].toString();
      final cover = stream is SeriesItem ? stream.displayIcon : (stream as Map<String, dynamic>)['cover']?.toString() ?? '';
      ref.read(watchProgressActionsProvider).saveHistory(
          ContentKey.make(ContentKey.series, seriesId), displayName, cover, '', _mode.key);
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
    final contentType = ContentKey.typeForPlayMode(_mode.key);
    final contentKey = ContentKey.make(contentType, streamId);
    if (_mode == ContentMode.live) {
      url = _repo.getLiveStreamUrl(streamId);
      resumeKey = null; // Live channels don't have a resume position.
    } else {
      final ext = stream is VodItem ? stream.containerExtension : (stream is Map<String, dynamic> ? (stream['container_extension'] ?? 'mp4') : 'mp4');
      url = _repo.getVodStreamUrl(streamId, ext);
      resumeKey = contentKey;
      ref.read(watchProgressActionsProvider).saveMeta(contentKey, displayName,
          stream is VodItem ? (stream.streamIcon ?? '') : (stream is Map<String, dynamic> ? (stream['stream_icon']?.toString() ?? '') : ''), url, _mode.key);
    }
    ref.read(watchProgressActionsProvider).saveHistory(contentKey, displayName, cover, url, _mode.key);

    List<Channel>? channelList;
    int? channelIndex;
    if (_mode == ContentMode.live) {
      channelList = _sortedStreams
          .whereType<Channel>()
          .toList();
      channelIndex = channelList.indexWhere((ch) => ch.id == streamId);
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

  /// Called from `.then(...)` callbacks of every push-and-pop screen
  /// (player, favorites, search, history, …). Invalidates the
  /// progress providers so the grid + Continue Watching rows refresh
  /// with whatever the user did inside the popped route.
  ///
  /// **Why the post-frame defer matters.** `.then` fires *during* the
  /// pop's last animation frame, while the popped route's internal
  /// `_ModalScope` (Flutter's per-route `GlobalKey<_ModalScopeState>`)
  /// is still being torn down. Invalidating providers synchronously
  /// here marks `home_screen` dirty for that same frame; the next
  /// `drawFrame` rebuilds the home subtree while the framework is
  /// still mid-cleanup of the popped route, and the GlobalKey
  /// reconciliation pass trips `_InactiveElements.remove` →
  /// `_elements.contains(element)` (framework.dart:2168). Deferring
  /// by one frame guarantees the cleanup is done before our rebuild
  /// runs. This is the root-cause fix — not a `route.isCurrent` /
  /// `_isDisposed` patch on a single call-site.
  void _refreshProgress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(watchProgressProvider);
      ref.invalidate(continueWatchingProvider);
    });
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
    // Grid is now allowed for Live too so channels show up as tiles (logos +
    // optional "now playing" subtitle) instead of an austere list.
    final showGrid = _gridView;

    // Watch only the resolved status (not the AsyncValue wrapper) so
    // ConnectivityProvider's internal state ticks don't rebuild the
    // entire Home on every reconnection probe. The offline→online
    // snackbar + retry side-effect lives in `ref.listenManual` set up
    // in initState, not here.
    final connectivityStatus = ref.watch(connectivityProvider
        .select((async) => async.valueOrNull ?? ConnectivityStatus.online));
    final isOffline = connectivityStatus == ConnectivityStatus.offline && _streams.isEmpty;

    // Watch providers — use `.select` on the heavy ones so an
    // unchanged sub-state (same Set of fav keys, same Map of
    // progress) skips the Home rebuild. Riverpod compares with `==`,
    // so a re-emit of an equivalent Set / Map is a no-op.
    final favKeys = ref.watch(favoritesProvider.select((s) => s.keys));
    final wlKeys = ref.watch(watchlistProvider.select((s) => s.keys));
    final progress = ref.watch(
            watchProgressProvider.select((async) => async.valueOrNull)) ??
        const <String, double>{};
    final continueItems = ref.watch(
            continueWatchingProvider.select((async) => async.valueOrNull)) ??
        const [];
    final collections = ref.watch(collectionsProvider);
    // Items lists are only needed for the special category sync
    // below — read (not watch) since that block is already guarded
    // by `_selectedCategory == '__favorites__'` / `__watchlist__`.
    final favItems = ref.read(favoritesProvider).items;
    final wlItems = ref.read(watchlistProvider).items;

    // Keep `_streams` in sync with the favourites/watchlist state when
    // the user is viewing a virtual category. The original
    // `onSpecialCategorySelected` snapshotted the provider's items at
    // click time, so removing a favourite afterwards left the grid
    // showing the now-stale list. Re-deriving here makes the grid
    // reactive — the next state change reaches the renderer through the
    // normal Riverpod rebuild path.
    // Set-based diff so swapping one favourite for another (length
    // unchanged) still triggers a refresh. Length-only comparison
    // missed that case and left the grid showing a stale entry.
    bool keySetChanged(List<Map<String, dynamic>> fresh) {
      final freshKeys = fresh
          .map((m) => m['key']?.toString() ?? '')
          .where((k) => k.isNotEmpty)
          .toSet();
      final currentKeys = _streams
          .map((m) => m is Map ? (m['key']?.toString() ?? '') : '')
          .where((k) => k.isNotEmpty)
          .toSet();
      return freshKeys.length != currentKeys.length ||
          !freshKeys.containsAll(currentKeys);
    }

    if (_selectedCategory == '__favorites__') {
      final fresh = favItems
          .where((e) => e.mode == _mode.key)
          .map((e) => e.toJson())
          .toList();
      if (keySetChanged(fresh)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCategory == '__favorites__') {
            setState(() => _streams = fresh);
          }
        });
      }
    } else if (_selectedCategory == '__watchlist__') {
      final fresh = wlItems
          .where((e) => e.mode == _mode.key)
          .map((e) => e.toJson())
          .toList();
      if (keySetChanged(fresh)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCategory == '__watchlist__') {
            setState(() => _streams = fresh);
          }
        });
      }
    }

    // Parental controls: filter categories and streams when locked.
    // Use `.select` on a tuple of (active, blockedIds) so Home only
    // rebuilds when one of those actually changes — not on every
    // unrelated parental notifier internal update.
    final parentalActive = ref.watch(parentalProvider
        .select((p) => p.isEnabled && !p.isUnlocked));
    final blockedIds = ref.watch(parentalProvider
        .select((p) => p.blockedCategoryIds));
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
      // Let the hero banner's blurred backdrop extend all the way to the top
      // of the window (under the transparent app bar) for a Plex-like feel.
      extendBodyBehindAppBar: true,
      drawer: _buildSidebarDrawer(collections, filteredCategories),
      appBar: HomeAppBar(
        segment: _segment,
        showGrid: showGrid,
        sortMode: _sortMode,
        selectedCategory: _selectedCategory,
        isCompact: MediaQuery.of(context).size.width < 900,
        // Drives the app-bar opacity fade-in as the user scrolls.
        scrollOffset: _mainScrollOffset,
        leadingMenuButton:
            MediaQuery.of(context).size.width < 900 && _segment != HomeSegment.home
                ? Builder(
                    // `Scaffold.of(ctx)` needs a context below the Scaffold —
                    // hence the Builder. Avoids the GlobalKey<ScaffoldState>
                    // pattern, which is the canonical trigger of the
                    // `_elements.contains(element)` framework assertion when
                    // the home subtree rebuilds during a route pop.
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  )
                : null,
        onSegmentChanged: (newSegment) {
          if (newSegment == _segment) return;
          if (newSegment == HomeSegment.home) {
            setState(() => _segment = HomeSegment.home);
            AppLogger.breadcrumb('navigation', 'Segment changed', data: {'segment': 'home'});
            // Lazy-load the cross-mode featured list the first time we
            // land on Accueil — `_init` may not have populated it yet
            // on a fresh app start.
            if (_accueilFeatured.isEmpty) _loadAccueilFeatured();
            return;
          }
          final newMode = newSegment.mode!;
          setState(() {
            _segment = newSegment;
            _mode = newMode;
            _streams = [];
            _selectedCategory = null;
            _recentlyAdded = [];
            _catchupPrograms = [];
            _selectionMode = false;
            _selectedItems = {};
            // Reset the ambient target so the new mode's hero is
            // free to push its own rotation item.
            _splitWallpaperItem = null;
            _splitHoveredItem = null;
          });
          AppLogger.breadcrumb('navigation', 'Segment changed', data: {'segment': newSegment.name});
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
        onFavoritesPressed: () => Navigator.push(context,
            fadeRoute(const FavoritesScreen()))
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
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          // Only care about the grid/list's scroll view, not horizontal
          // strips inside the hero/continue/recently rows.
          if (n.metrics.axis != Axis.vertical) return false;
          _mainScrollOffset.value = n.metrics.pixels;
          return false;
        },
        child: _loading
          ? const SkeletonList()
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ExcludeSemantics(child: Icon(Icons.error_outline, size: 48, color: Colors.red)),
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(_error!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _init, child: Text(AppLocalizations.of(context)!.reessayer)),
            ]))
          : isOffline
          ? OfflineContent(onRetryConnection: _retryConnection)
          : _segment == HomeSegment.home
          ? AccueilView(
              featured: _accueilFeatured,
              catchupPrograms: _catchupPrograms,
              topInset: kToolbarHeight + MediaQuery.paddingOf(context).top,
              onPlayItem: _openItemByType,
              onPlayFavorite: _openFavorite,
              onPlayCatchup: _openCatchupProgram,
              onPlayContinueItem: (item) {
                // Item already carries url + resume key — go straight
                // to the player and let it resume from the saved
                // position (same flow the legacy split-view header
                // used).
                Navigator.push(
                  context,
                  slideRoute(PlayerScreen(
                    url: item.url,
                    title: item.name,
                    resumeKey: item.id,
                  )),
                ).then((_) => _refreshProgress());
              },
            )
          : Builder(builder: (context) {
              // Header rows that used to sit above the Row(sidebar + grid)
              // stack — now moved INTO the grid's scroll view so they collapse
              // naturally as the user scrolls down. Builds the "Plex-style"
              // full-bleed feel and gives the grid the vertical room it needs.
              // The hero itself bakes the app-bar top-padding inside — the
              // blurred backdrop now goes ALL the way to the top of the
              // window (extendBodyBehindAppBar = true), no grey band below
              // the tabs.
              final double topInset =
                  kToolbarHeight + MediaQuery.paddingOf(context).top;
              final headerChild = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mode != ContentMode.live && _recentlyAdded.isNotEmpty)
                    HomeHero(
                      topInset: topInset,
                      items: parentalActive
                          ? _recentlyAdded
                              .where((item) =>
                                  !blockedIds.contains(getStreamCategoryId(item)))
                              .toList()
                          : _recentlyAdded,
                      onPlayItem: _playStream,
                      // Films / Séries menus now also paint a full-
                      // screen ambient wallpaper behind the page (see
                      // the Stack wrap below). Hero stays transparent
                      // so the wallpaper image bleeds through into the
                      // shelves with no visible "band" in between.
                      transparentBackdrop: true,
                      onCurrentItemChanged: (item) {
                        if (!mounted) return;
                        setState(() => _splitWallpaperItem = item);
                      },
                    )
                  else
                    // Live mode shows no hero, so the first row would slide
                    // under the transparent app bar (extendBodyBehindAppBar).
                    // Pad it down by the bar + status-bar height instead.
                    SizedBox(height: topInset),
                  ContinueWatchingRow(
                    items: continueItems,
                    onTap: (item) {
                      // Clear the hover override before we navigate so
                      // the wallpaper doesn't dangle on a hovered item
                      // while the user is inside the player.
                      if (_splitHoveredItem != null) {
                        setState(() => _splitHoveredItem = null);
                      }
                      Navigator.push(
                        context,
                        slideRoute(PlayerScreen(
                          url: item.url,
                          title: item.name,
                          resumeKey: item.id,
                        )),
                      ).then((_) => _refreshProgress());
                    },
                    onItemHover: (item, isHovered) =>
                        _onSplitItemHover(item, isHovered),
                  ),
                  if (_mode == ContentMode.live)
                    CatchupRow(
                      programs: _catchupPrograms,
                      onTap: (prog) {
                        if (!checkPremiumAccess(context, ref, Feature.catchupReplay)) return;
                        String url;
                        if (prog.serverLocalStart.isNotEmpty) {
                          url = _repo.getTimeshiftUrlFromLocal(
                              prog.streamId, prog.serverLocalStart, prog.durationMin);
                        } else {
                          url = _repo.getTimeshiftUrl(
                              prog.streamId, prog.startUtc, prog.durationMin);
                        }
                        Navigator.push(
                            context,
                            slideRoute(PlayerScreen(
                              url: url,
                              title:
                                  '${prog.title} (${AppLocalizations.of(context)!.replay})',
                              streamId: prog.streamId,
                              isCatchup: true,
                            )));
                      },
                    ),
                  RecentlyAddedRow(
                    items: parentalActive
                        ? _recentlyAdded
                            .where((item) =>
                                !blockedIds.contains(getStreamCategoryId(item)))
                            .toList()
                        : _recentlyAdded,
                    mode: _mode,
                    onTap: (item) {
                      if (_splitHoveredItem != null) {
                        setState(() => _splitHoveredItem = null);
                      }
                      _playStream(item);
                    },
                    onItemHover: (item, isHovered) =>
                        _onSplitItemHover(item, isHovered),
                  ),
                  // Sort chips + inline search — VOD / Séries only.
                  // Live keeps its legacy AppBar sort menu (it relies
                  // on the `number` mode which makes no sense for
                  // films / series).
                  if (_mode != ContentMode.live)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        DS.space.md,
                        DS.padding.screenHorizontal,
                        DS.space.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: CatalogSortChips(
                              selection:
                                  CatalogSortMode.fromId(_sortMode),
                              onChanged: (m) {
                                setState(() => _sortMode = m.id);
                                _saveSortMode();
                                _resetPaginationIfActive();
                              },
                            ),
                          ),
                          SizedBox(width: DS.space.sm),
                          InlineSearchField(
                            query: _searchQuery,
                            onChanged: (v) => setState(
                                () => _searchQuery = v.toLowerCase()),
                          ),
                        ],
                      ),
                    ),
                ],
              );
              final wallpaperTarget =
                  _splitHoveredItem ?? _splitWallpaperItem;
              final body = Column(children: [
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
              // Stream content area — Stack so we can pin the
              // FocusedItemPreview panel at the bottom over the grid.
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
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
                    // VOD / Séries get the inline search field from
                    // the header above (`InlineSearchField`) — hide
                    // the internal one to avoid double bars.
                    hideInternalSearch: _mode != ContentMode.live,
                    onItemHover: _onGridItemHover,
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
                        if (_selectedItems.contains(key)) {
                          _selectedItems.remove(key);
                        } else {
                          _selectedItems.add(key);
                        }
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
                    // Hero + continue watching + recently added are part of
                    // the grid's scroll view so they collapse away on scroll.
                    // We always pass the headerChild (even for virtual
                    // categories like __favorites__) because it also carries
                    // the app-bar-height spacer required by
                    // extendBodyBehindAppBar.
                    headerChild: headerChild,
                  );
                }),
                    ),
                    // Bottom-of-grid Apple-TV+-style preview panel.
                    // `IgnorePointer` inside `FocusedItemPreview`
                    // keeps clicks reaching the cards below.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: FocusedItemPreview(
                        item: _gridHoveredItem,
                        mode: _mode,
                      ),
                    ),
                  ],
                ),
              ),
            ]);
                },
              )),
          ]);
              // Wrap the split-view body in a full-screen Stack with
              // the ambient wallpaper at the bottom (Films / Séries
              // only — Live has no hero rotation to drive a target).
              if (_mode != ContentMode.live) {
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AmbientWallpaper(item: wallpaperTarget),
                    body,
                  ],
                );
              }
              return body;
            }),
      ),
    ),
    );
  }

}
