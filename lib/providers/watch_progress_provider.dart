import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/watch_progress.dart';

/// All watch progress ratios: key -> [0.0, 1.0]
final watchProgressProvider = FutureProvider<Map<String, double>>((ref) async {
  return WatchProgress.loadAll();
});

/// Items currently being watched (for "Continuer a regarder" banner)
final continueWatchingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return WatchProgress.loadContinueWatching();
});

/// Watch history
class HistoryNotifier extends StateNotifier<AsyncValue<List<Map<String, String>>>> {
  HistoryNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await WatchProgress.loadHistory());
  }

  Future<void> deleteEntry(String key) async {
    await WatchProgress.deleteHistoryEntry(key);
    await load();
  }

  Future<void> reInsertEntry(Map<String, String> entry) async {
    await WatchProgress.reInsertHistoryEntry(entry);
    await load();
  }

  Future<void> clearAll() async {
    await WatchProgress.clearHistory();
    state = const AsyncValue.data([]);
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<Map<String, String>>>>((ref) {
  return HistoryNotifier();
});
