import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';

class FavoritesState {
  final Set<String> keys;
  final List<Map<String, dynamic>> items;

  const FavoritesState({this.keys = const {}, this.items = const []});
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier() : super(const FavoritesState()) {
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.favorites(AppConfig.activeProfileId));
    if (raw == null) {
      state = const FavoritesState();
      return;
    }
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    final keys = list.map((e) => e['key']?.toString() ?? e['stream_id']?.toString() ?? '').toSet();
    state = FavoritesState(keys: keys, items: list);
  }

  Future<void> toggle(String key, Map<String, dynamic> item) async {
    final p = await SharedPreferences.getInstance();
    final items = List<Map<String, dynamic>>.from(state.items);
    final keys = Set<String>.from(state.keys);

    if (keys.contains(key)) {
      keys.remove(key);
      items.removeWhere((e) => (e['key'] ?? e['stream_id']?.toString()) == key);
    } else {
      keys.add(key);
      items.add({...item, 'key': key});
    }

    await p.setString(StorageKeys.favorites(AppConfig.activeProfileId), jsonEncode(items));
    state = FavoritesState(keys: keys, items: items);
  }

  bool isFavorite(String key) => state.keys.contains(key);
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});

// Watchlist uses the same pattern
class WatchlistState {
  final Set<String> keys;
  final List<Map<String, dynamic>> items;

  const WatchlistState({this.keys = const {}, this.items = const []});
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier() : super(const WatchlistState()) {
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.watchlist(AppConfig.activeProfileId));
    if (raw == null) {
      state = const WatchlistState();
      return;
    }
    final list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    final keys = list.map((e) => e['key']?.toString() ?? '').toSet();
    state = WatchlistState(keys: keys, items: list);
  }

  Future<void> toggle(String key, Map<String, dynamic> item) async {
    final p = await SharedPreferences.getInstance();
    final items = List<Map<String, dynamic>>.from(state.items);
    final keys = Set<String>.from(state.keys);

    if (keys.contains(key)) {
      keys.remove(key);
      items.removeWhere((e) => e['key'] == key);
    } else {
      keys.add(key);
      items.add({...item, 'key': key});
    }

    await p.setString(StorageKeys.watchlist(AppConfig.activeProfileId), jsonEncode(items));
    state = WatchlistState(keys: keys, items: items);
  }

  bool isInWatchlist(String key) => state.keys.contains(key);
}

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  return WatchlistNotifier();
});
