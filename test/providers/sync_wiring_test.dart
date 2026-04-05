import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/providers/favorites_provider.dart';
import 'package:unistream/providers/collections_provider.dart';
import 'package:unistream/providers/theme_provider.dart';
import 'package:unistream/providers/locale_provider.dart';
import 'package:unistream/services/sync_service.dart';

/// Sync wiring tests.
///
/// These verify that every notifier that should push to SyncService does so
/// without crashing when Supabase is NOT initialised (_ready == false, so
/// push* calls are safe no-ops).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
    AppConfig.serverUrl = '';
    AppConfig.username = '';
  });

  group('SyncService safety', () {
    test('SyncService.instance is accessible as a singleton', () {
      final service = SyncService.instance;
      expect(service, isNotNull);
      expect(identical(service, SyncService.instance), true);
    });

    test('pushFavorites is a no-op when Supabase is not initialized', () {
      // Should not throw even though Supabase is not set up
      expect(
        () => SyncService.instance.pushFavorites({'k': {'name': 'x'}}, 'favorite'),
        returnsNormally,
      );
    });

    test('pushCollections is a no-op when Supabase is not initialized', () {
      expect(
        () => SyncService.instance.pushCollections([
          {'id': '1', 'name': 'Col'}
        ]),
        returnsNormally,
      );
    });

    test('pushSetting is a no-op when Supabase is not initialized', () {
      expect(
        () => SyncService.instance.pushSetting('themeMode', 'dark'),
        returnsNormally,
      );
    });
  });

  group('FavoritesNotifier sync wiring', () {
    test('toggle calls _pushSync without error', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // toggle internally calls _pushSync -> SyncService.instance.pushFavorites
      // which is a no-op because Supabase is not initialized.
      await notifier.toggle('ch_1', {'name': 'Channel 1', 'stream_id': 1});
      expect(notifier.isFavorite('ch_1'), true);
    });

    test('removing a favorite also calls _pushSync without error', () async {
      final notifier = FavoritesNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('ch_1', {'name': 'Channel 1'});
      await notifier.toggle('ch_1', {'name': 'Channel 1'});
      expect(notifier.isFavorite('ch_1'), false);
    });
  });

  group('WatchlistNotifier sync wiring', () {
    test('toggle calls _pushSync without error', () async {
      final notifier = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('movie_1', {'name': 'Movie 1'});
      expect(notifier.isInWatchlist('movie_1'), true);
    });

    test('removing from watchlist calls _pushSync without error', () async {
      final notifier = WatchlistNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.toggle('movie_1', {'name': 'Movie 1'});
      await notifier.toggle('movie_1', {'name': 'Movie 1'});
      expect(notifier.isInWatchlist('movie_1'), false);
    });
  });

  group('CollectionsNotifier sync wiring', () {
    test('create calls _pushSync without error', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('Sync Test');
      expect(col['name'], 'Sync Test');
      expect(notifier.state.length, 1);
    });

    test('delete calls _pushSync without error', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('To Delete');
      await notifier.delete(col['id'] as String);
      expect(notifier.state, isEmpty);
    });

    test('addItem calls _pushSync without error', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('Items Col');
      await notifier.addItem(col['id'] as String, {'key': 'x', 'name': 'X'});
      final items =
          (notifier.state[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1);
    });

    test('removeItem calls _pushSync without error', () async {
      final notifier = CollectionsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final col = await notifier.create('Items Col');
      await notifier.addItem(col['id'] as String, {'key': 'x', 'name': 'X'});
      await notifier.removeItem(col['id'] as String, 'x');
      final items =
          (notifier.state[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items, isEmpty);
    });
  });

  group('ThemeNotifier sync wiring', () {
    test('setTheme calls SyncService.pushSetting without error', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();

      await notifier.setTheme(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      await notifier.setTheme(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);
    });
  });

  group('LocaleNotifier sync wiring', () {
    test('setLocale calls SyncService.pushSetting without error', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();

      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, const Locale('en'));

      await notifier.setLocale(const Locale('fr'));
      expect(notifier.state, const Locale('fr'));
    });
  });
}
