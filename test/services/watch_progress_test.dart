import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/services/watch_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
  });

  group('WatchProgress.save / getPosition', () {
    test('saves and retrieves position', () async {
      await WatchProgress.save(
        'movie_1',
        const Duration(seconds: 300),
        const Duration(seconds: 7200),
      );
      final pos = await WatchProgress.getPosition('movie_1');
      expect(pos, const Duration(seconds: 300));
    });

    test('ignores save when duration < 10 seconds', () async {
      await WatchProgress.save(
        'short_clip',
        const Duration(seconds: 3),
        const Duration(seconds: 5),
      );
      final pos = await WatchProgress.getPosition('short_clip');
      expect(pos, isNull);
    });

    test('clears progress when ratio > 95%', () async {
      // First save at 50%
      await WatchProgress.save(
        'movie_2',
        const Duration(seconds: 500),
        const Duration(seconds: 1000),
      );
      expect(await WatchProgress.getPosition('movie_2'), isNotNull);

      // Now save at 96%
      await WatchProgress.save(
        'movie_2',
        const Duration(seconds: 960),
        const Duration(seconds: 1000),
      );
      expect(await WatchProgress.getPosition('movie_2'), isNull);
    });

    test('getPosition returns null for unknown key', () async {
      final pos = await WatchProgress.getPosition('nonexistent');
      expect(pos, isNull);
    });
  });

  group('WatchProgress.clear', () {
    test('removes position and duration', () async {
      await WatchProgress.save(
        'movie_3',
        const Duration(seconds: 100),
        const Duration(seconds: 1000),
      );
      await WatchProgress.clear('movie_3');
      final pos = await WatchProgress.getPosition('movie_3');
      expect(pos, isNull);
    });
  });

  group('WatchProgress.loadAll', () {
    test('returns empty map when no data', () async {
      final result = await WatchProgress.loadAll();
      expect(result, isEmpty);
    });

    test('returns ratios for saved items', () async {
      await WatchProgress.save(
        'a',
        const Duration(seconds: 500),
        const Duration(seconds: 1000),
      );
      await WatchProgress.save(
        'b',
        const Duration(seconds: 250),
        const Duration(seconds: 1000),
      );
      final result = await WatchProgress.loadAll();
      expect(result['a'], closeTo(0.5, 0.01));
      expect(result['b'], closeTo(0.25, 0.01));
    });
  });

  group('WatchProgress.saveMeta / loadContinueWatching', () {
    test('returns empty list when no data', () async {
      final result = await WatchProgress.loadContinueWatching();
      expect(result, isEmpty);
    });

    test('returns items with position >= 30s and meta', () async {
      // Save progress at 60s/1000s
      await WatchProgress.save(
        'movie_cw',
        const Duration(seconds: 60),
        const Duration(seconds: 1000),
      );
      await WatchProgress.saveMeta(
        'movie_cw',
        'Test Movie',
        'cover.png',
        'http://stream.url',
        'vod',
      );

      final result = await WatchProgress.loadContinueWatching();
      expect(result.length, 1);
      expect(result[0].name, 'Test Movie');
      expect(result[0].id, 'movie_cw');
    });

    test('excludes items with position < 30s', () async {
      await WatchProgress.save(
        'too_short',
        const Duration(seconds: 20),
        const Duration(seconds: 1000),
      );
      await WatchProgress.saveMeta(
        'too_short',
        'Short',
        'cover.png',
        'http://stream.url',
        'vod',
      );
      final result = await WatchProgress.loadContinueWatching();
      expect(result, isEmpty);
    });

    test('excludes items without meta', () async {
      await WatchProgress.save(
        'no_meta',
        const Duration(seconds: 60),
        const Duration(seconds: 1000),
      );
      final result = await WatchProgress.loadContinueWatching();
      expect(result, isEmpty);
    });
  });

  group('WatchProgress history', () {
    test('loadHistory returns empty list when no data', () async {
      final result = await WatchProgress.loadHistory();
      expect(result, isEmpty);
    });

    test('saveHistory and loadHistory roundtrip', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'cover1.png', 'http://url1', 'vod',
      );
      await WatchProgress.saveHistory(
        'h2', 'Movie 2', 'cover2.png', 'http://url2', 'vod',
      );
      final result = await WatchProgress.loadHistory();
      expect(result.length, 2);
    });

    test('saveHistory deduplicates by key (latest first)', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1 old', 'old.png', 'http://old', 'vod',
      );
      await WatchProgress.saveHistory(
        'h1', 'Movie 1 new', 'new.png', 'http://new', 'vod',
      );
      final result = await WatchProgress.loadHistory();
      expect(result.length, 1);
      expect(result[0].name, 'Movie 1 new');
    });

    test('deleteHistoryEntry removes entry', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      await WatchProgress.saveHistory(
        'h2', 'Movie 2', 'c.png', 'http://u', 'vod',
      );
      await WatchProgress.deleteHistoryEntry('h1');
      final result = await WatchProgress.loadHistory();
      expect(result.length, 1);
      expect(result[0].key, 'h2');
    });

    test('clearHistory removes all entries', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      await WatchProgress.clearHistory();
      final result = await WatchProgress.loadHistory();
      expect(result, isEmpty);
    });

    test('reInsertHistoryEntry restores entry', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      final history = await WatchProgress.loadHistory();
      final entry = history.first;
      await WatchProgress.deleteHistoryEntry('h1');
      expect((await WatchProgress.loadHistory()), isEmpty);

      await WatchProgress.reInsertHistoryEntry(entry);
      final restored = await WatchProgress.loadHistory();
      expect(restored.length, 1);
      expect(restored[0].key, 'h1');
    });

    test('deleteHistoryEntry with no data is a no-op', () async {
      await WatchProgress.deleteHistoryEntry('nonexistent');
      final result = await WatchProgress.loadHistory();
      expect(result, isEmpty);
    });
  });

  group('WatchProgress.getDuration', () {
    test('returns duration after save', () async {
      await WatchProgress.save('dur_1', const Duration(seconds: 100), const Duration(seconds: 3600));
      final dur = await WatchProgress.getDuration('dur_1');
      expect(dur, const Duration(seconds: 3600));
    });

    test('returns null for unknown key', () async {
      final dur = await WatchProgress.getDuration('unknown');
      expect(dur, isNull);
    });
  });

  group('WatchProgress.getProgress', () {
    test('returns both position and duration', () async {
      await WatchProgress.save('prog_1', const Duration(seconds: 500), const Duration(seconds: 7200));
      final p = await WatchProgress.getProgress('prog_1');
      expect(p.position, const Duration(seconds: 500));
      expect(p.duration, const Duration(seconds: 7200));
    });

    test('returns nulls for unknown key', () async {
      final p = await WatchProgress.getProgress('nope');
      expect(p.position, isNull);
      expect(p.duration, isNull);
    });

    test('returns null after clear', () async {
      await WatchProgress.save('clr_1', const Duration(seconds: 60), const Duration(seconds: 600));
      await WatchProgress.clear('clr_1');
      final p = await WatchProgress.getProgress('clr_1');
      expect(p.position, isNull);
      expect(p.duration, isNull);
    });
  });
}
