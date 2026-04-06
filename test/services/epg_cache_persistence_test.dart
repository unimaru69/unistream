import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/models/profile.dart';
import 'package:unistream/services/xtream_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.profiles = [
      Profile(id: 'test_profile', name: 'Test', serverUrl: 'http://test', username: 'u', password: 'p'),
    ];
    AppConfig.activeProfileId = 'test_profile';
    XtreamApi.clearEpgCache();
  });

  group('EPG cache persistence', () {
    test('loadEpgCacheFromDisk loads valid entries', () async {
      // Seed SharedPreferences with cached EPG data
      final now = DateTime.now();
      final cacheData = {
        'short_epg_123_8': {
          'data': {'epg_listings': [{'title': 'Test Program'}]},
          'ts': now.toIso8601String(),
        },
      };
      SharedPreferences.setMockInitialValues({
        StorageKeys.epgCache('test_profile'): jsonEncode(cacheData),
      });

      await XtreamApi.loadEpgCacheFromDisk();
      expect(XtreamApi.epgCacheSize, 1);

      // Verify getCachedEpgNow can access the loaded data
      // (won't match current time, but the cache entry exists)
    });

    test('loadEpgCacheFromDisk skips expired entries', () async {
      final expired = DateTime.now().subtract(const Duration(hours: 1));
      final cacheData = {
        'short_epg_456_8': {
          'data': {'epg_listings': []},
          'ts': expired.toIso8601String(),
        },
      };
      SharedPreferences.setMockInitialValues({
        StorageKeys.epgCache('test_profile'): jsonEncode(cacheData),
      });

      await XtreamApi.loadEpgCacheFromDisk();
      expect(XtreamApi.epgCacheSize, 0);
    });

    test('loadEpgCacheFromDisk handles missing data gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      await XtreamApi.loadEpgCacheFromDisk();
      expect(XtreamApi.epgCacheSize, 0);
    });

    test('loadEpgCacheFromDisk handles corrupt data gracefully', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.epgCache('test_profile'): 'not valid json',
      });
      // Should not throw
      await XtreamApi.loadEpgCacheFromDisk();
      expect(XtreamApi.epgCacheSize, 0);
    });

    test('StorageKeys.epgCache returns correct key', () {
      expect(StorageKeys.epgCache('p1'), 'epg_cache_p1');
    });
  });
}
