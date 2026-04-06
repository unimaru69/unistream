import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';
import '../models/collection_data.dart';
import '../models/favorite_item.dart';
import '../services/collections_service.dart';
import '../services/sync_service.dart';

class CollectionsNotifier extends StateNotifier<List<CollectionData>> {
  CollectionsNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    state = await CollectionsService.loadCollections();
  }

  Future<CollectionData> create(String name, {String? mode}) async {
    final col = await CollectionsService.saveCollection(name, mode: mode);
    await load();
    _pushSync();
    return col;
  }

  Future<void> delete(String id) async {
    await CollectionsService.deleteCollection(id);
    await load();
    _pushSync();
  }

  Future<void> addItem(String collectionId, FavoriteItem item) async {
    await CollectionsService.addToCollection(collectionId, item);
    await load();
    _pushSync();
  }

  Future<void> removeItem(String collectionId, String itemKey) async {
    await CollectionsService.removeFromCollection(collectionId, itemKey);
    await load();
    _pushSync();
  }

  /// Merge remote collections into local state (add missing, merge items).
  Future<void> mergeFromRemote(List<Map<String, dynamic>> remote) async {
    if (remote.isEmpty) return;
    final local = await CollectionsService.loadCollections();
    final localIds = local.map((c) => c.id).toSet();
    bool changed = false;

    for (final rc in remote) {
      final remoteId = rc['collection_id']?.toString() ?? rc['id']?.toString() ?? '';
      if (remoteId.isEmpty) continue;

      final localIdx = local.indexWhere((c) => c.id == remoteId);

      if (localIdx < 0) {
        // Collection doesn't exist locally — add it
        local.add(CollectionData.fromLegacy({...rc, 'id': remoteId}));
        changed = true;
      } else {
        // Merge items: add remote items missing locally
        final localCol = local[localIdx];
        final localItemKeys = localCol.items.map((e) => e.key).toSet();
        final remoteItems = (rc['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final newItems = <FavoriteItem>[];
        for (final ri in remoteItems) {
          final rk = ri['key']?.toString() ?? '';
          if (rk.isNotEmpty && !localItemKeys.contains(rk)) {
            newItems.add(FavoriteItem.fromLegacy(rk, Map<String, dynamic>.from(ri)));
            changed = true;
          }
        }
        if (newItems.isNotEmpty) {
          local[localIdx] = localCol.copyWith(items: [...localCol.items, ...newItems]);
        }
      }
    }

    if (changed) {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        StorageKeys.collections(AppConfig.activeProfileId),
        jsonEncode(local.map((c) => c.toJson()).toList()),
      );
      state = local;
    }
  }

  void _pushSync() {
    SyncService.instance.pushCollections(state.map((c) => c.toJson()).toList());
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<CollectionData>>((ref) {
  return CollectionsNotifier();
});
