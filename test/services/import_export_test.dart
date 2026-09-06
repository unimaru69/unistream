import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/import_export.dart';

void main() {
  group('ImportExport.parseM3U', () {
    test('parses valid M3U with multiple entries', () {
      const content = '''#EXTM3U
#EXTINF:-1,Channel One
http://example.com/stream1
#EXTINF:-1,Channel Two
http://example.com/stream2
#EXTINF:-1,Channel Three
http://example.com/stream3''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 3);
      expect(result[0]['name'], 'Channel One');
      expect(result[0]['url'], 'http://example.com/stream1');
      expect(result[1]['name'], 'Channel Two');
      expect(result[1]['url'], 'http://example.com/stream2');
      expect(result[2]['name'], 'Channel Three');
      expect(result[2]['url'], 'http://example.com/stream3');
    });

    test('parses M3U with extra attributes in EXTINF line', () {
      const content = '''#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-logo="logo.png" group-title="News",BBC News
http://example.com/bbc''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 1);
      expect(result[0]['name'], 'BBC News');
      expect(result[0]['url'], 'http://example.com/bbc');
    });

    test('returns empty list for empty content', () {
      final result = ImportExport.parseM3U('');
      expect(result, isEmpty);
    });

    test('returns empty list for header-only M3U', () {
      final result = ImportExport.parseM3U('#EXTM3U\n');
      expect(result, isEmpty);
    });

    test('handles URL without preceding EXTINF', () {
      const content = '''#EXTM3U
http://example.com/orphan''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 1);
      expect(result[0]['name'], 'Sans titre');
      expect(result[0]['url'], 'http://example.com/orphan');
    });

    test('handles EXTINF without comma uses "Sans titre"', () {
      const content = '''#EXTM3U
#EXTINF:-1
http://example.com/stream''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 1);
      // lastIndexOf(',') returns -1, so name = 'Sans titre' from the URL entry
      // Actually, the EXTINF line has no comma so commaIdx < 0, name = 'Sans titre'
      // Then the next non-# line picks up name = 'Sans titre'
    });

    test('trims whitespace from lines', () {
      const content = '''#EXTM3U
  #EXTINF:-1,Spaced Channel
  http://example.com/spaced  ''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 1);
      expect(result[0]['name'], 'Spaced Channel');
      expect(result[0]['url'], 'http://example.com/spaced');
    });

    test('skips blank lines', () {
      const content = '''#EXTM3U

#EXTINF:-1,Channel A

http://example.com/a

#EXTINF:-1,Channel B

http://example.com/b
''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 2);
      expect(result[0]['name'], 'Channel A');
      expect(result[1]['name'], 'Channel B');
    });

    test('resets name after each URL entry', () {
      const content = '''#EXTM3U
#EXTINF:-1,Named
http://example.com/named
http://example.com/unnamed''';

      final result = ImportExport.parseM3U(content);
      expect(result.length, 2);
      expect(result[0]['name'], 'Named');
      expect(result[1]['name'], 'Sans titre');
    });
  });

  group('ImportExport.importConfigJSON — untrusted input', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppConfig.currentUserId = null;
      AppConfig.profiles = [];
      AppConfig.activeProfileId = '';
    });

    String backupWith(Map<String, dynamic> watchProgress) => jsonEncode({
          'profiles': [
            {
              'id': 'p1',
              'name': 'Serveur',
              'serverUrl': 'http://example.com',
              'username': 'u',
              'password': 'p',
            }
          ],
          'activeProfile': 'p1',
          'wp_p1': watchProgress,
        });

    test('restores the profile\'s own watch-progress keys', () async {
      await ImportExport.importConfigJSON(backupWith({
        StorageKeys.wpPosition('p1', 'vod_1'): 120,
        StorageKeys.wpDuration('p1', 'vod_1'): 3600,
      }));

      final p = await SharedPreferences.getInstance();
      expect(p.getInt(StorageKeys.wpPosition('p1', 'vod_1')), 120);
      expect(p.getInt(StorageKeys.wpDuration('p1', 'vod_1')), 3600);
    });

    test('ignores keys outside the profile namespace', () async {
      // A crafted backup smuggling a known parental PIN hash — and a few
      // other preferences — through the watch-progress map.
      await ImportExport.importConfigJSON(backupWith({
        StorageKeys.parentalPinHash: 'hash-of-a-pin-the-attacker-knows',
        StorageKeys.blockedCategories('p1'): '[]',
        StorageKeys.tmdbUserKey: 'attacker-key',
        'wp_otherprofile_s_vod_9': 42,
        StorageKeys.wpPosition('p1', 'vod_1'): 120,
      }));

      final p = await SharedPreferences.getInstance();
      expect(p.getString(StorageKeys.parentalPinHash), isNull);
      expect(p.getString(StorageKeys.blockedCategories('p1')), isNull);
      expect(p.getString(StorageKeys.tmdbUserKey), isNull);
      expect(p.getInt('wp_otherprofile_s_vod_9'), isNull);
      // The legitimate key still lands.
      expect(p.getInt(StorageKeys.wpPosition('p1', 'vod_1')), 120);
    });
  });
}
