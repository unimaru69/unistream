import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/providers/collections_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
  });

  group('CollectionsNotifier', () {
    test('initial state is empty after load', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, isEmpty);
    });

    test('create adds a collection and reloads state', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('Test Collection');
      expect(col['name'], 'Test Collection');
      expect(notifier.state.length, 1);
      expect(notifier.state[0]['name'], 'Test Collection');
    });

    test('create with mode stores the mode', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('Live Favs', mode: 'live');
      expect(col['mode'], 'live');
    });

    test('delete removes a collection', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('To Delete');
      expect(notifier.state.length, 1);

      await notifier.delete(col['id'] as String);
      expect(notifier.state, isEmpty);
    });

    test('addItem adds an item to a collection', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('My Col');
      await notifier.addItem(
        col['id'] as String,
        {'key': 'ch1', 'name': 'Channel 1'},
      );

      final items =
          (notifier.state[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
      expect(items[0]['key'], 'ch1');
    });

    test('removeItem removes an item from a collection', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('My Col');
      await notifier.addItem(
        col['id'] as String,
        {'key': 'ch1', 'name': 'Channel 1'},
      );
      await notifier.addItem(
        col['id'] as String,
        {'key': 'ch2', 'name': 'Channel 2'},
      );
      await notifier.removeItem(col['id'] as String, 'ch1');

      final items =
          (notifier.state[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
      expect(items[0]['key'], 'ch2');
    });

    test('multiple collections are independent', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col1 = await notifier.create('Col 1');
      await notifier.create('Col 2');
      await notifier.addItem(
        col1['id'] as String,
        {'key': 'a', 'name': 'A'},
      );

      expect(notifier.state.length, 2);
      final items1 =
          (notifier.state[0]['items'] as List).cast<Map<String, dynamic>>();
      final items2 =
          (notifier.state[1]['items'] as List).cast<Map<String, dynamic>>();
      expect(items1.length, 1);
      expect(items2.length, 0);
    });
  });
}
