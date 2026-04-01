import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/collections_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
  });

  group('CollectionsService', () {
    test('loadCollections returns empty list when no data', () async {
      final result = await CollectionsService.loadCollections();
      expect(result, isEmpty);
    });

    test('saveCollection creates a new collection', () async {
      final col = await CollectionsService.saveCollection('My Collection');
      expect(col['name'], 'My Collection');
      expect(col['id'], isNotEmpty);
      expect(col['items'], isEmpty);
    });

    test('saveCollection with mode stores the mode', () async {
      final col =
          await CollectionsService.saveCollection('Live Favs', mode: 'live');
      expect(col['mode'], 'live');
    });

    test('loadCollections returns saved collections', () async {
      await CollectionsService.saveCollection('Col1');
      await CollectionsService.saveCollection('Col2');
      final result = await CollectionsService.loadCollections();
      expect(result.length, 2);
      expect(result[0]['name'], 'Col1');
      expect(result[1]['name'], 'Col2');
    });

    test('deleteCollection removes the collection', () async {
      final col = await CollectionsService.saveCollection('To Delete');
      await CollectionsService.deleteCollection(col['id'] as String);
      final result = await CollectionsService.loadCollections();
      expect(result, isEmpty);
    });

    test('deleteCollection with non-existent id is a no-op', () async {
      await CollectionsService.saveCollection('Keep');
      await CollectionsService.deleteCollection('nonexistent');
      final result = await CollectionsService.loadCollections();
      expect(result.length, 1);
    });

    test('addToCollection adds an item', () async {
      final col = await CollectionsService.saveCollection('My Col');
      final item = {'key': 'item1', 'name': 'Channel 1'};
      await CollectionsService.addToCollection(col['id'] as String, item);

      final result = await CollectionsService.loadCollections();
      final items = (result[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
      expect(items[0]['key'], 'item1');
    });

    test('addToCollection avoids duplicates', () async {
      final col = await CollectionsService.saveCollection('My Col');
      final item = {'key': 'item1', 'name': 'Channel 1'};
      await CollectionsService.addToCollection(col['id'] as String, item);
      await CollectionsService.addToCollection(col['id'] as String, item);

      final result = await CollectionsService.loadCollections();
      final items = (result[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
    });

    test('addToCollection allows different items', () async {
      final col = await CollectionsService.saveCollection('My Col');
      await CollectionsService.addToCollection(
          col['id'] as String, {'key': 'a', 'name': 'A'});
      await CollectionsService.addToCollection(
          col['id'] as String, {'key': 'b', 'name': 'B'});

      final result = await CollectionsService.loadCollections();
      final items = (result[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 2);
    });

    test('removeFromCollection removes the correct item', () async {
      final col = await CollectionsService.saveCollection('My Col');
      await CollectionsService.addToCollection(
          col['id'] as String, {'key': 'a', 'name': 'A'});
      await CollectionsService.addToCollection(
          col['id'] as String, {'key': 'b', 'name': 'B'});
      await CollectionsService.removeFromCollection(
          col['id'] as String, 'a');

      final result = await CollectionsService.loadCollections();
      final items = (result[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
      expect(items[0]['key'], 'b');
    });

    test('removeFromCollection with non-existent key is a no-op', () async {
      final col = await CollectionsService.saveCollection('My Col');
      await CollectionsService.addToCollection(
          col['id'] as String, {'key': 'a', 'name': 'A'});
      await CollectionsService.removeFromCollection(
          col['id'] as String, 'nonexistent');

      final result = await CollectionsService.loadCollections();
      final items = (result[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
    });

    test('collections are profile-scoped', () async {
      AppConfig.activeProfileId = 'profile_a';
      await CollectionsService.saveCollection('Col A');

      AppConfig.activeProfileId = 'profile_b';
      final result = await CollectionsService.loadCollections();
      expect(result, isEmpty);

      await CollectionsService.saveCollection('Col B');
      final resultB = await CollectionsService.loadCollections();
      expect(resultB.length, 1);
      expect(resultB[0]['name'], 'Col B');

      // Switch back to profile_a
      AppConfig.activeProfileId = 'profile_a';
      final resultA = await CollectionsService.loadCollections();
      expect(resultA.length, 1);
      expect(resultA[0]['name'], 'Col A');
    });
  });
}
