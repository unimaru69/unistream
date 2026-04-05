import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _pushSync() {
    SyncService.instance.pushCollections(state);
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<Map<String, dynamic>>>((ref) {
  return CollectionsNotifier();
});
