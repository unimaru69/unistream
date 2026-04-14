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

    if (keys.contains(key)) {
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
    _pushSync();
  }

  /// Merge remote items into local state (union, remote fills gaps).
  Future<void> mergeFromRemote(Map<String, dynamic> remote) async {
    if (remote.isEmpty) return;
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

    if (keys.contains(key)) {
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
    _pushSync();
  }

  /// Merge remote items into local state (union, remote fills gaps).
  Future<void> mergeFromRemote(Map<String, dynamic> remote) async {
    if (remote.isEmpty) return;
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

  bool isInWatchlist(String key) => state.keys.contains(key);
}

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  return WatchlistNotifier();
});
