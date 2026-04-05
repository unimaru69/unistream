import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/supabase_config.dart';
import 'package:unistream/services/sync_service.dart';

void main() {
  group('SupabaseConfig.profileHash', () {
    test('produces correct SHA-256 hash', () {
      AppConfig.serverUrl = 'http://example.com';
      AppConfig.username = 'testuser';

      final expected = sha256
          .convert(utf8.encode('http://example.com:testuser'))
          .toString();
      expect(SupabaseConfig.profileHash, expected);
    });

    test('returns empty string when serverUrl is empty', () {
      AppConfig.serverUrl = '';
      AppConfig.username = 'testuser';
      expect(SupabaseConfig.profileHash, '');
    });

    test('returns empty string when username is empty', () {
      AppConfig.serverUrl = 'http://example.com';
      AppConfig.username = '';
      expect(SupabaseConfig.profileHash, '');
    });

    test('computeProfileHash matches profileHash getter', () {
      AppConfig.serverUrl = 'http://srv.io';
      AppConfig.username = 'alice';

      final fromGetter = SupabaseConfig.profileHash;
      final fromMethod =
          SupabaseConfig.computeProfileHash('http://srv.io', 'alice');
      expect(fromGetter, fromMethod);
    });

    test('different credentials produce different hashes', () {
      final h1 = SupabaseConfig.computeProfileHash('http://a.com', 'user1');
      final h2 = SupabaseConfig.computeProfileHash('http://b.com', 'user2');
      expect(h1, isNot(equals(h2)));
    });

    test('hash is 64-char lowercase hex string', () {
      final h = SupabaseConfig.computeProfileHash('http://x.com', 'bob');
      expect(h.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(h), isTrue);
    });
  });

  group('SyncService push methods (no Supabase client)', () {
    late SyncService service;

    setUp(() {
      AppConfig.serverUrl = 'http://test.com';
      AppConfig.username = 'user';
      service = SyncService.instance;
    });

    tearDown(() {
      service.dispose();
    });

    test('pushFavorites does not throw', () {
      expect(
        () => service.pushFavorites({'key1': {'name': 'test'}}, 'favorites'),
        returnsNormally,
      );
    });

    test('pushCollections does not throw', () {
      expect(
        () => service.pushCollections([
          {'id': 'c1', 'name': 'My List', 'items': []}
        ]),
        returnsNormally,
      );
    });

    test('pushWatchProgress does not throw', () {
      expect(
        () => service.pushWatchProgress(
            'movie1', 5000, 120000, {'title': 'Movie'}),
        returnsNormally,
      );
    });

    test('pushSetting does not throw', () {
      expect(
        () => service.pushSetting('theme', 'dark'),
        returnsNormally,
      );
    });
  });

  group('SyncService pull methods (no Supabase client)', () {
    late SyncService service;

    setUp(() {
      AppConfig.serverUrl = 'http://test.com';
      AppConfig.username = 'user';
      service = SyncService.instance;
    });

    test('pullFavorites returns empty map', () async {
      final result = await service.pullFavorites('favorites');
      expect(result, isEmpty);
    });

    test('pullCollections returns empty list', () async {
      final result = await service.pullCollections();
      expect(result, isEmpty);
    });

    test('pullWatchProgress returns empty map', () async {
      final result = await service.pullWatchProgress();
      expect(result, isEmpty);
    });

    test('pullSettings returns empty map', () async {
      final result = await service.pullSettings();
      expect(result, isEmpty);
    });
  });

  group('SyncService debounce', () {
    late SyncService service;

    setUp(() {
      AppConfig.serverUrl = 'http://test.com';
      AppConfig.username = 'user';
      service = SyncService.instance;
    });

    tearDown(() {
      service.dispose();
    });

    test('rapid push calls are batched without throwing', () async {
      // Without a Supabase client these are no-ops, but the debounce
      // timer should fire without errors.
      service.pushFavorites({'a': {'n': '1'}}, 'favorites');
      service.pushFavorites({'b': {'n': '2'}}, 'favorites');
      service.pushSetting('lang', 'fr');
      service.pushWatchProgress('ep1', 1000, 60000, {});

      // Wait past the 500ms debounce window.
      await Future.delayed(const Duration(milliseconds: 700));
      // No exceptions = success.
    });
  });

  group('SyncService realtime (no Supabase client)', () {
    test('startRealtime / stopRealtime do not throw', () {
      final service = SyncService.instance;
      AppConfig.serverUrl = 'http://test.com';
      AppConfig.username = 'user';

      expect(() => service.startRealtime((table) {}), returnsNormally);
      expect(() => service.stopRealtime(), returnsNormally);
      service.dispose();
    });
  });
}
