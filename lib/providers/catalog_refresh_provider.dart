import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';
import '../repositories/content_repository.dart';
import 'api_provider.dart';

/// How long the catalogue may go unrefreshed before returning to the app
/// triggers an automatic pull.
enum CatalogRefreshInterval {
  manual(0),
  sixHours(21600),
  twelveHours(43200),
  daily(86400);

  const CatalogRefreshInterval(this.seconds);
  final int seconds;

  static CatalogRefreshInterval fromSeconds(int? seconds) {
    if (seconds == null) return CatalogRefreshInterval.sixHours;
    return CatalogRefreshInterval.values
            .where((i) => i.seconds == seconds)
            .firstOrNull ??
        CatalogRefreshInterval.sixHours;
  }
}

class CatalogRefreshState {
  const CatalogRefreshState({
    this.lastRefresh,
    this.isRefreshing = false,
    this.generation = 0,
    this.interval = CatalogRefreshInterval.sixHours,
  });

  /// When the catalogue was last pulled from the panel, `null` when never.
  final DateTime? lastRefresh;
  final bool isRefreshing;

  /// Bumped after every completed refresh. Screens holding their own copy
  /// of the catalogue (the home grid keeps `_streams` in local state)
  /// listen on this and reload.
  final int generation;

  final CatalogRefreshInterval interval;

  /// True when a return to the foreground should trigger a pull.
  bool get isStale {
    if (interval == CatalogRefreshInterval.manual) return false;
    final last = lastRefresh;
    if (last == null) return true;
    return DateTime.now().difference(last).inSeconds >= interval.seconds;
  }

  CatalogRefreshState copyWith({
    DateTime? lastRefresh,
    bool? isRefreshing,
    int? generation,
    CatalogRefreshInterval? interval,
  }) {
    return CatalogRefreshState(
      lastRefresh: lastRefresh ?? this.lastRefresh,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      generation: generation ?? this.generation,
      interval: interval ?? this.interval,
    );
  }
}

/// Owns the "go and re-pull the catalogue from the Xtream panel" policy.
///
/// [XtreamApi] caches stream lists for 5 minutes, but that TTL is a rate
/// limiter — it stops the UI hammering the panel while the user browses.
/// It was never a freshness policy: nothing went back to the server on
/// its own to pick up the films, episodes and channels the provider added
/// since launch, and pull-to-refresh was served straight from that same
/// cache. This notifier is the missing policy: an explicit action, an
/// optional staleness check on resume, and a [generation] counter screens
/// can watch.
///
/// A cold start already fetches everything (the stream cache is in-memory
/// only), so process launch counts as a refresh — see [markFreshStart].
class CatalogRefreshNotifier extends StateNotifier<CatalogRefreshState> {
  CatalogRefreshNotifier(this._ref) : super(const CatalogRefreshState()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intervalSecs = prefs.getInt(StorageKeys.catalogAutoRefreshInterval);
      final lastMs = prefs.getInt(
          StorageKeys.catalogLastRefresh(AppConfig.activeProfileId));
      if (!mounted) return;
      state = state.copyWith(
        interval: CatalogRefreshInterval.fromSeconds(intervalSecs),
        lastRefresh:
            lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null,
      );
    } catch (e, st) {
      AppLogger.warning(LogModule.api, 'Catalog refresh prefs load failed',
          error: e, stackTrace: st);
    }
  }

  Future<void> setInterval(CatalogRefreshInterval interval) async {
    state = state.copyWith(interval: interval);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        StorageKeys.catalogAutoRefreshInterval, interval.seconds);
  }

  /// Process launch (and profile switch) pull everything from the network
  /// anyway. Stamp now so the staleness check doesn't immediately fire a
  /// second round of the same requests.
  Future<void> markFreshStart() async {
    await _stampNow();
  }

  /// Drop the catalogue caches and re-pull. Returns false when a refresh
  /// was already running.
  Future<bool> refresh({String reason = 'manuel'}) async {
    if (state.isRefreshing) return false;
    state = state.copyWith(isRefreshing: true);
    AppLogger.info(LogModule.api, 'Catalogue refresh started ($reason)');
    try {
      _ref.read(contentRepositoryProvider).clearStreamCache();

      // Providers that wrap the catalogue endpoints. The home grid
      // doesn't go through them (it keeps its own `_streams`), which is
      // exactly why `generation` exists.
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(liveStreamsProvider);
      _ref.invalidate(vodStreamsProvider);
      _ref.invalidate(seriesListProvider);

      await _stampNow();
      if (!mounted) return true;
      state = state.copyWith(generation: state.generation + 1);
      AppLogger.info(LogModule.api,
          'Catalogue refresh done (generation ${state.generation})');
      return true;
    } finally {
      if (mounted) state = state.copyWith(isRefreshing: false);
    }
  }

  /// Refresh only when the catalogue is older than the chosen interval.
  Future<void> refreshIfStale() async {
    if (!state.isStale) return;
    await refresh(reason: 'auto (retour au premier plan)');
  }

  Future<void> _stampNow() async {
    final now = DateTime.now();
    if (mounted) state = state.copyWith(lastRefresh: now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        StorageKeys.catalogLastRefresh(AppConfig.activeProfileId),
        now.millisecondsSinceEpoch,
      );
    } catch (e, st) {
      AppLogger.warning(LogModule.api, 'Catalog refresh stamp failed',
          error: e, stackTrace: st);
    }
  }
}

final catalogRefreshProvider =
    StateNotifierProvider<CatalogRefreshNotifier, CatalogRefreshState>((ref) {
  return CatalogRefreshNotifier(ref);
});
