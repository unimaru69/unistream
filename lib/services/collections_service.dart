import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/collection_data.dart';
import '../models/favorite_item.dart';

class CollectionsService {
  static String get _prefsKey => StorageKeys.collections(AppConfig.activeProfileId);

  /// Load all custom collections for the active profile.
  static Future<List<CollectionData>> loadCollections() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => CollectionData.fromLegacy(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> _save(List<CollectionData> collections) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(collections.map((c) => c.toJson()).toList()));
  }

  /// Create a new collection with the given name, optionally scoped to a mode.
  static Future<CollectionData> saveCollection(String name, {String? mode}) async {
    final collections = await loadCollections();
    final col = CollectionData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      items: [],
      mode: mode,
    );
    collections.add(col);
    await _save(collections);
    return col;
  }

  /// Delete a collection by id.
  static Future<void> deleteCollection(String id) async {
    final collections = await loadCollections();
    collections.removeWhere((c) => c.id == id);
    await _save(collections);
  }

  /// Add an item to a collection.
  static Future<void> addToCollection(String collectionId, FavoriteItem item) async {
    final collections = await loadCollections();
    final updated = collections.map((col) {
      if (col.id == collectionId) {
        if (col.items.any((e) => e.key == item.key)) return col;
        return col.copyWith(items: [...col.items, item]);
      }
      return col;
    }).toList();
    await _save(updated);
  }

  /// Remove an item from a collection by key.
  static Future<void> removeFromCollection(String collectionId, String itemKey) async {
    final collections = await loadCollections();
    final updated = collections.map((col) {
      if (col.id == collectionId) {
        return col.copyWith(items: col.items.where((e) => e.key != itemKey).toList());
      }
      return col;
    }).toList();
    await _save(updated);
  }
}
