import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/continue_watching_item.dart';
import '../models/history_entry.dart';
import '../services/watch_progress.dart';

/// All watch progress ratios: key -> [0.0, 1.0]
final watchProgressProvider = FutureProvider<Map<String, double>>((ref) async {
  return WatchProgress.loadAll();
});

/// Items currently being watched (for "Continuer a regarder" banner)
final continueWatchingProvider = FutureProvider<List<ContinueWatchingItem>>((ref) async {
  return WatchProgress.loadContinueWatching();
});

/// ── Write facade for watch progress ──
///
/// Exposes all WatchProgress write operations and automatically invalidates
/// the read providers so the UI stays in sync.
class WatchProgressActions {
  WatchProgressActions(this._ref);
  final Ref _ref;

  /// Save playback position. Removes entry if content is >95% done.
  Future<void> save(String key, Duration pos, Duration dur) async {
    await WatchProgress.save(key, pos, dur);
    _invalidate();
  }

  /// Save metadata for "Continue watching" banner.
  Future<void> saveMeta(String key, String name, String cover, String url, String mode) async {
    await WatchProgress.saveMeta(key, name, cover, url, mode);
    _invalidate();
  }

  /// Save an entry in the watch history.
  Future<void> saveHistory(String key, String name, String cover, String url, String mode) async {
    await WatchProgress.saveHistory(key, name, cover, url, mode);
    _ref.invalidate(historyProvider);
  }

  /// Get saved position for a key.
  Future<Duration?> getPosition(String key) => WatchProgress.getPosition(key);

  /// Get both position and duration for a key.
  Future<({Duration? position, Duration? duration})> getProgress(String key) =>
      WatchProgress.getProgress(key);

  /// Clear progress for a key.
  Future<void> clear(String key) async {
    await WatchProgress.clear(key);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(watchProgressProvider);
    _ref.invalidate(continueWatchingProvider);
  }
}

final watchProgressActionsProvider = Provider<WatchProgressActions>((ref) {
  return WatchProgressActions(ref);
});

/// Watch history
class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryEntry>>> {
  HistoryNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final history = await WatchProgress.loadHistory();
    if (!mounted) return;
    state = AsyncValue.data(history);
  }

  Future<void> deleteEntry(String key) async {
    await WatchProgress.deleteHistoryEntry(key);
    if (!mounted) return;
    await load();
  }

  Future<void> reInsertEntry(HistoryEntry entry) async {
    await WatchProgress.reInsertHistoryEntry(entry);
    if (!mounted) return;
    await load();
  }

  Future<void> clearAll() async {
    await WatchProgress.clearHistory();
    if (!mounted) return;
    state = const AsyncValue.data([]);
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryEntry>>>((ref) {
  return HistoryNotifier();
});
