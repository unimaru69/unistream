import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/sync_service.dart';
import 'package:unistream/services/watch_progress.dart';
import 'package:unistream/services/xtream_api.dart';

/// Regression suite for the credential leak in `user_watch_progress`.
///
/// Xtream stream URLs carry the panel login + password in their path, and
/// the watch-progress meta blob used to be pushed to Supabase verbatim —
/// storing every user's IPTV credentials in cleartext server-side. The
/// contract these tests pin down:
///
///   * nothing leaving the device carries a URL (hence a password);
///   * `ext` travels instead, so any device can rebuild its own URL;
///   * Continue Watching still resumes for an item first seen elsewhere.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.serverUrl = 'http://test.server:8080';
    AppConfig.username = 'testuser';
    AppConfig.password = 'testpass';
    AppConfig.activeProfileId = 'test_profile';
  });

  group('SyncService.scrubMetaForSync', () {
    test('drops url and keeps everything else', () {
      final scrubbed = SyncService.scrubMetaForSync({
        'name': 'Blade Runner',
        'title': 'Blade Runner',
        'cover': 'http://cdn/poster.jpg',
        'url': 'http://test.server:8080/movie/testuser/testpass/456.mkv',
        'ext': 'mkv',
        'mode': 'vod',
        'ts': 1234,
      });

      expect(scrubbed.containsKey('url'), isFalse);
      expect(scrubbed, {
        'name': 'Blade Runner',
        'title': 'Blade Runner',
        'cover': 'http://cdn/poster.jpg',
        'ext': 'mkv',
        'mode': 'vod',
        'ts': 1234,
      });
    });

    test('the encoded payload never carries the panel password', () {
      final payload = jsonEncode(SyncService.scrubMetaForSync({
        'name': 'Blade Runner',
        'url': XtreamApi.getVodStreamUrl('456', 'mkv'),
        'ext': 'mkv',
      }));

      expect(payload.contains(AppConfig.password), isFalse);
      expect(payload.contains(AppConfig.username), isFalse);
    });

    test('leaves the caller\'s map untouched', () {
      final original = {'name': 'X', 'url': 'http://secret'};
      SyncService.scrubMetaForSync(original);
      expect(original.containsKey('url'), isTrue);
    });
  });

  group('XtreamApi.streamUrlForContentKey', () {
    test('rebuilds a VOD URL with the given extension', () {
      expect(
        XtreamApi.streamUrlForContentKey('vod_456', ext: 'mkv'),
        'http://test.server:8080/movie/testuser/testpass/456.mkv',
      );
    });

    test('rebuilds an episode URL', () {
      expect(
        XtreamApi.streamUrlForContentKey('ep_789', ext: 'ts'),
        'http://test.server:8080/series/testuser/testpass/789.ts',
      );
    });

    test('rebuilds a live URL and ignores the extension', () {
      expect(
        XtreamApi.streamUrlForContentKey('live_42', ext: 'mkv'),
        'http://test.server:8080/live/testuser/testpass/42.m3u8',
      );
    });

    test('returns null for series-level and unparseable keys', () {
      expect(XtreamApi.streamUrlForContentKey('series_12'), isNull);
      expect(XtreamApi.streamUrlForContentKey('12345'), isNull);
      expect(XtreamApi.streamUrlForContentKey('vod:12345'), isNull);
    });
  });

  group('WatchProgress.extFromStreamUrl', () {
    test('extracts the container extension', () {
      expect(
        WatchProgress.extFromStreamUrl(
            'http://test.server:8080/movie/testuser/testpass/456.MKV'),
        'mkv',
      );
      expect(
        WatchProgress.extFromStreamUrl(
            'http://test.server:8080/live/testuser/testpass/42.m3u8'),
        'm3u8',
      );
    });

    test('returns empty for a URL with no usable suffix', () {
      expect(WatchProgress.extFromStreamUrl(''), '');
      expect(WatchProgress.extFromStreamUrl('http://host/movie/u/p/456'), '');
      expect(WatchProgress.extFromStreamUrl('http://host/movie/u/p/456.'), '');
    });
  });

  group('WatchProgress.resolveUrl', () {
    test('prefers the locally captured URL', () {
      expect(
        WatchProgress.resolveUrl('vod_456', const {
          'url': 'http://other.host/movie/u/p/456.avi',
          'ext': 'mkv',
        }),
        'http://other.host/movie/u/p/456.avi',
      );
    });

    test('rebuilds from the synced ext when there is no local URL', () {
      expect(
        WatchProgress.resolveUrl('vod_456', const {'ext': 'mkv'}),
        'http://test.server:8080/movie/testuser/testpass/456.mkv',
      );
    });

    test('falls back to mp4 when ext is missing or blank', () {
      expect(
        WatchProgress.resolveUrl('vod_456', const {}),
        'http://test.server:8080/movie/testuser/testpass/456.mp4',
      );
      expect(
        WatchProgress.resolveUrl('vod_456', const {'ext': ''}),
        'http://test.server:8080/movie/testuser/testpass/456.mp4',
      );
    });

    test('returns empty string when nothing can be rebuilt', () {
      expect(WatchProgress.resolveUrl('series_12', const {}), '');
    });
  });

  group('end to end', () {
    test('saveMeta stores ext alongside the local URL', () async {
      await WatchProgress.saveMeta(
        'vod_456',
        'Blade Runner',
        'http://cdn/poster.jpg',
        XtreamApi.getVodStreamUrl('456', 'mkv'),
        'vod',
      );

      final p = await SharedPreferences.getInstance();
      final meta = jsonDecode(
          p.getString(StorageKeys.wpMeta('test_profile', 'vod_456'))!) as Map;
      expect(meta['ext'], 'mkv');
      expect(meta['url'], contains('testpass'));
    });

    test('an item synced from another device still resumes', () async {
      // Shape a row arriving from Supabase leaves behind: title, cover
      // and ext, but no URL — the credentials stayed on the other device.
      SharedPreferences.setMockInitialValues({
        StorageKeys.wpPosition('test_profile', 'vod_456'): 300,
        StorageKeys.wpDuration('test_profile', 'vod_456'): 7200,
        StorageKeys.wpMeta('test_profile', 'vod_456'): jsonEncode({
          'name': 'Blade Runner',
          'cover': 'http://cdn/poster.jpg',
          'ext': 'mkv',
          'mode': 'vod',
          'ts': 1234,
        }),
      });

      final items = await WatchProgress.loadContinueWatching();
      expect(items, hasLength(1));
      expect(
        items.single.url,
        'http://test.server:8080/movie/testuser/testpass/456.mkv',
      );
    });
  });
}
