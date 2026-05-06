import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/favorite_item.dart';
import '../services/sync_service.dart';

class FavoritesState {
  final Set<String> keys;
  final List<FavoriteItem> items;

  const FavoritesState({this.keys = const {}, this.items = const []});
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier() : super(const FavoritesState()) {
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = p.getString(StorageKeys.favorites(AppConfig.activeProfileId));
    if (raw == null) {
      if (!mounted) return;
      state = const FavoritesState();
      return;
    }
    final list = (jsonDecode(raw) as List).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final key = (map['_key'] ?? map['key'] ?? map['stream_id'])?.toString() ?? '';
      return FavoriteItem.fromLegacy(key, map);
    }).toList();
    final keys = list.map((e) => e.key).toSet();
    if (!mounted) return;
    state = FavoritesState(keys: keys, items: list);
  }

  Future<void> toggle(String key, FavoriteItem item) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final items = List<FavoriteItem>.from(state.items);
    final keys = Set<String>.from(state.keys);
    final wasFavorite = keys.contains(key);

    if (wasFavorite) {
      keys.remove(key);
      items.removeWhere((e) => e.key == key);
    } else {
      keys.add(key);
      items.add(item);
    }

    await p.setString(StorageKeys.favorites(AppConfig.activeProfileId),
        jsonEncode(items.map((e) => e.toJson()).toList()));
    if (!mounted) return;
    state = FavoritesState(keys: keys, items: items);
    if (wasFavorite) {
      // Soft-delete on Supabase so the removal propagates to other
      // devices (the upsert in _pushSync only re-states what's still
      // present locally — it can't express "this key is gone").
      SyncService.instance.deleteFavorite(key, 'favorite');
    } else {
      _pushSync();
    }
  }

  /// Reconcile local state with what we just pulled from Supabase.
  ///
  /// When [authoritative] is true (the default for callers that
  /// just performed a successful pull or received a realtime event),
  /// local items missing from [remote] are *removed*. This is what
  /// makes cross-device removals propagate — tvOS soft-deletes a
  /// favourite, the deleted=false filter on pull strips it from the
  /// returned map, and iOS now drops the corresponding local entry.
  ///
  /// When [authoritative] is false, behaviour falls back to the old
  /// union semantics (add gaps, never remove). Use this when the
  /// pull might be partial / unreliable.
  Future<void> mergeFromRemote(
    Map<String, dynamic> remote, {
    bool authoritative = true,
  }) async {
    if (!authoritative && remote.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final items = List<FavoriteItem>.from(state.items);
    final keys = Set<String>.from(state.keys);
    bool changed = false;

    // Add any remote-only items.
    for (final entry in remote.entries) {
      if (!keys.contains(entry.key)) {
        keys.add(entry.key);
        final map = Map<String, dynamic>.from(entry.value as Map);
        items.add(FavoriteItem.fromLegacy(entry.key, map));
        changed = true;
      }
    }

    // Authoritative reconciliation: drop local items the server no
    // longer knows about (= soft-deleted from another device).
    if (authoritative) {
      final keysToRemove = keys.where((k) => !remote.containsKey(k)).toList();
      if (keysToRemove.isNotEmpty) {
        keys.removeAll(keysToRemove);
        items.removeWhere((it) => keysToRemove.contains(it.key));
        changed = true;
      }
    }

    if (changed) {
      await p.setString(StorageKeys.favorites(AppConfig.activeProfileId),
          jsonEncode(items.map((e) => e.toJson()).toList()));
      if (!mounted) return;
      state = FavoritesState(keys: keys, items: items);
    }
  }

  void _pushSync() {
    final map = <String, dynamic>{};
    for (final item in state.items) {
      if (item.key.isNotEmpty) map[item.key] = item.toJson();
    }
    SyncService.instance.pushFavorites(map, 'favorite');
  }

  /// Public wrapper around `_pushSync` — used by `ContentKeyMigration`
  /// to force a fresh upsert of the entire local list under canonical
  /// keys. Idempotent on Supabase (upsert with onConflict).
  void repushAll() => _pushSync();

  bool isFavorite(String key) => state.keys.contains(key);
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});

// Watchlist uses the same pattern
class WatchlistState {
  final Set<String> keys;
  final List<FavoriteItem> items;

  const WatchlistState({this.keys = const {}, this.items = const []});
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier() : super(const WatchlistState()) {
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = p.getString(StorageKeys.watchlist(AppConfig.activeProfileId));
    if (raw == null) {
      if (!mounted) return;
      state = const WatchlistState();
      return;
    }
    final list = (jsonDecode(raw) as List).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final key = (map['_key'] ?? map['key'])?.toString() ?? '';
      return FavoriteItem.fromLegacy(key, map);
    }).toList();
    final keys = list.map((e) => e.key).toSet();
    if (!mounted) return;
    state = WatchlistState(keys: keys, items: list);
  }

  Future<void> toggle(String key, FavoriteItem item) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final items = List<FavoriteItem>.from(state.items);
    final keys = Set<String>.from(state.keys);
    final wasInList = keys.contains(key);

    if (wasInList) {
      keys.remove(key);
      items.removeWhere((e) => e.key == key);
    } else {
      keys.add(key);
      items.add(item);
    }

    await p.setString(StorageKeys.watchlist(AppConfig.activeProfileId),
        jsonEncode(items.map((e) => e.toJson()).toList()));
    if (!mounted) return;
    state = WatchlistState(keys: keys, items: items);
    if (wasInList) {
      SyncService.instance.deleteFavorite(key, 'watchlist');
    } else {
      _pushSync();
    }
  }

  /// Reconcile local watchlist with the latest pull. See the matching
  /// docstring on `FavoritesNotifier.mergeFromRemote` for the
  /// authoritative-flag rationale.
  Future<void> mergeFromRemote(
    Map<String, dynamic> remote, {
    bool authoritative = true,
  }) async {
    if (!authoritative && remote.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final items = List<FavoriteItem>.from(state.items);
    final keys = Set<String>.from(state.keys);
    bool changed = false;

    for (final entry in remote.entries) {
      if (!keys.contains(entry.key)) {
        keys.add(entry.key);
        final map = Map<String, dynamic>.from(entry.value as Map);
        items.add(FavoriteItem.fromLegacy(entry.key, map));
        changed = true;
      }
    }

    if (authoritative) {
      final keysToRemove = keys.where((k) => !remote.containsKey(k)).toList();
      if (keysToRemove.isNotEmpty) {
        keys.removeAll(keysToRemove);
        items.removeWhere((it) => keysToRemove.contains(it.key));
        changed = true;
      }
    }

    if (changed) {
      await p.setString(StorageKeys.watchlist(AppConfig.activeProfileId),
          jsonEncode(items.map((e) => e.toJson()).toList()));
      if (!mounted) return;
      state = WatchlistState(keys: keys, items: items);
    }
  }

  void _pushSync() {
    final map = <String, dynamic>{};
    for (final item in state.items) {
      if (item.key.isNotEmpty) map[item.key] = item.toJson();
    }
    SyncService.instance.pushFavorites(map, 'watchlist');
  }

  /// See `FavoritesNotifier.repushAll` — same purpose, watchlist scope.
  void repushAll() => _pushSync();

  bool isInWatchlist(String key) => state.keys.contains(key);
}

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  return WatchlistNotifier();
});
