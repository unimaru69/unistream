import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';
import '../services/collections_service.dart';
import '../services/sync_service.dart';

class CollectionsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CollectionsNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    state = await CollectionsService.loadCollections();
  }

  Future<Map<String, dynamic>> create(String name, {String? mode}) async {
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

  Future<void> addItem(String collectionId, Map<String, dynamic> item) async {
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
    final localIds = local.map((c) => c['id']?.toString() ?? c['collection_id']?.toString()).toSet();
    bool changed = false;

    for (final rc in remote) {
      final remoteId = rc['collection_id']?.toString() ?? rc['id']?.toString() ?? '';
      if (remoteId.isEmpty) continue;

      final localMatch = local.cast<Map<String, dynamic>?>().firstWhere(
        (c) => (c!['id']?.toString() ?? '') == remoteId,
        orElse: () => null,
      );

      if (localMatch == null) {
        // Collection doesn't exist locally — add it
        local.add({
          'id': remoteId,
          'name': rc['name'] ?? '',
          'items': rc['items'] ?? [],
          if (rc['mode'] != null) 'mode': rc['mode'],
        });
        changed = true;
      } else {
        // Merge items: add remote items missing locally
        final localItems = (localMatch['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final localItemKeys = localItems.map((e) => e['key']?.toString() ?? '').toSet();
        final remoteItems = (rc['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final ri in remoteItems) {
          final rk = ri['key']?.toString() ?? '';
          if (rk.isNotEmpty && !localItemKeys.contains(rk)) {
            localItems.add(Map<String, dynamic>.from(ri));
            changed = true;
          }
        }
        localMatch['items'] = localItems;
      }
    }

    if (changed) {
      // Persist merged collections and update state
      final p = await SharedPreferences.getInstance();
      await p.setString(
        StorageKeys.collections(AppConfig.activeProfileId),
        jsonEncode(local),
      );
      state = local;
    }
  }

  void _pushSync() {
    SyncService.instance.pushCollections(state);
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<Map<String, dynamic>>>((ref) {
  return CollectionsNotifier();
});
