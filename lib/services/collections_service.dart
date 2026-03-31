import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class CollectionsService {
  static String get _prefsKey => 'collections_${AppConfig.activeProfileId}';

  /// Load all custom collections for the active profile.
  /// Each collection: {id, name, items: [{key, name, cover, mode}]}
  static Future<List<Map<String, dynamic>>> loadCollections() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> _save(List<Map<String, dynamic>> collections) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(collections));
  }

  /// Create a new collection with the given name, optionally scoped to a mode.
  static Future<Map<String, dynamic>> saveCollection(String name, {String? mode}) async {
    final collections = await loadCollections();
    final col = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'items': <Map<String, dynamic>>[],
      if (mode != null) 'mode': mode,
    };
    collections.add(col);
    await _save(collections);
    return col;
  }

  /// Delete a collection by id.
  static Future<void> deleteCollection(String id) async {
    final collections = await loadCollections();
    collections.removeWhere((c) => c['id'] == id);
    await _save(collections);
  }

  /// Add an item to a collection.
  static Future<void> addToCollection(String collectionId, Map<String, dynamic> item) async {
    final collections = await loadCollections();
    for (final col in collections) {
      if (col['id'] == collectionId) {
        final items = (col['items'] as List).cast<Map<String, dynamic>>();
        // Avoid duplicates
        if (items.any((e) => e['key'] == item['key'])) return;
        items.add(item);
        col['items'] = items;
        break;
      }
    }
    await _save(collections);
  }

  /// Remove an item from a collection by key.
  static Future<void> removeFromCollection(String collectionId, String itemKey) async {
    final collections = await loadCollections();
    for (final col in collections) {
      if (col['id'] == collectionId) {
        final items = (col['items'] as List).cast<Map<String, dynamic>>();
        items.removeWhere((e) => e['key'] == itemKey);
        col['items'] = items;
        break;
      }
    }
    await _save(collections);
  }
}
