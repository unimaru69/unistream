import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/models/favorite_item.dart';
import 'package:unistream/providers/favorites_provider.dart';

FavoriteItem _item(String key, {String name = ''}) =>
    FavoriteItem(key: key, name: name, mode: 'live');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
  });

  group('FavoritesNotifier', () {
    test('initial state has empty keys and items', () {
      final notifier = FavoritesNotifier();
      expect(notifier.state.keys, isEmpty);
      expect(notifier.state.items, isEmpty);
    });

    test('toggle adds a favorite', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      expect(notifier.state.keys.contains('ch_1'), true);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.name, 'Channel 1');
    });

    test('toggle removes a favorite when already present', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      expect(notifier.state.keys.contains('ch_1'), true);

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      expect(notifier.state.keys.contains('ch_1'), false);
      expect(notifier.state.items, isEmpty);
    });

    test('isFavorite returns correct state', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isFavorite('ch_1'), false);
      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      expect(notifier.isFavorite('ch_1'), true);
    });

    test('toggle persists to SharedPreferences', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));

      final notifier2 = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier2.isFavorite('ch_1'), true);
      expect(notifier2.state.items.length, 1);
    });

    test('multiple favorites can coexist', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      await notifier.toggle('ch_2', _item('ch_2', name: 'Channel 2'));
      await notifier.toggle('ch_3', _item('ch_3', name: 'Channel 3'));
      expect(notifier.state.keys.length, 3);
      expect(notifier.state.items.length, 3);
    });

    test('toggle only removes the specified key', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));
      await notifier.toggle('ch_2', _item('ch_2', name: 'Channel 2'));
      await notifier.toggle('ch_1', _item('ch_1', name: 'Channel 1'));

      expect(notifier.isFavorite('ch_1'), false);
      expect(notifier.isFavorite('ch_2'), true);
      expect(notifier.state.items.length, 1);
    });
  });

  group('WatchlistNotifier', () {
    test('initial state has empty keys and items', () {
      final notifier = WatchlistNotifier();
      expect(notifier.state.keys, isEmpty);
      expect(notifier.state.items, isEmpty);
    });

    test('toggle adds to watchlist', () async {
      final notifier = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('movie_1', _item('movie_1', name: 'Movie 1'));
      expect(notifier.isInWatchlist('movie_1'), true);
    });

    test('toggle removes from watchlist', () async {
      final notifier = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('movie_1', _item('movie_1', name: 'Movie 1'));
      await notifier.toggle('movie_1', _item('movie_1', name: 'Movie 1'));
      expect(notifier.isInWatchlist('movie_1'), false);
    });

    test('toggle persists to SharedPreferences', () async {
      final notifier = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('movie_1', _item('movie_1', name: 'Movie 1'));

      final notifier2 = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier2.isInWatchlist('movie_1'), true);
    });
  });

  group('FavoritesState', () {
    test('default constructor has empty keys and items', () {
      const state = FavoritesState();
      expect(state.keys, isEmpty);
      expect(state.items, isEmpty);
    });

    test('constructor accepts custom keys and items', () {
      final state = FavoritesState(
        keys: {'a', 'b'},
        items: [
          const FavoriteItem(key: 'a', name: 'A'),
          const FavoriteItem(key: 'b', name: 'B'),
        ],
      );
      expect(state.keys.length, 2);
      expect(state.items.length, 2);
    });
  });

  group('WatchlistState', () {
    test('default constructor has empty keys and items', () {
      const state = WatchlistState();
      expect(state.keys, isEmpty);
      expect(state.items, isEmpty);
    });
  });

  group('FavoriteItem', () {
    test('fromLegacy converts old map format', () {
      final item = FavoriteItem.fromLegacy('live:123', {
        'name': 'Test Channel',
        'stream_icon': 'http://icon.png',
        '_mode': 'live',
        'stream_id': '123',
        'category_id': '5',
      });
      expect(item.key, 'live:123');
      expect(item.name, 'Test Channel');
      expect(item.mode, 'live');
      expect(item.streamId, '123');
      expect(item.categoryId, '5');
    });

    test('toJson and fromJson roundtrip', () {
      const item = FavoriteItem(
        key: 'vod:42',
        name: 'My Movie',
        cover: 'http://cover.jpg',
        mode: 'vod',
        streamId: '42',
      );
      final json = item.toJson();
      final restored = FavoriteItem.fromJson(json);
      expect(restored, item);
    });
  });
}
