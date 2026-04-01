import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import 'package:unistream/services/watch_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.activeProfileId = 'test_profile';
  });

  group('HistoryNotifier', () {
    test('initial state is loading then data', () async {
      final notifier = HistoryNotifier();
      // Initially loading
      expect(notifier.state.isLoading, true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Then resolves to empty data
      expect(notifier.state.hasValue, true);
      expect(notifier.state.value, isEmpty);
    });

    test('load populates state from service', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'cover.png', 'http://url', 'vod',
      );
      final notifier = HistoryNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value![0]['key'], 'h1');
    });

    test('deleteEntry removes entry and reloads', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      await WatchProgress.saveHistory(
        'h2', 'Movie 2', 'c.png', 'http://u', 'vod',
      );
      final notifier = HistoryNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await notifier.deleteEntry('h1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value![0]['key'], 'h2');
    });

    test('reInsertEntry restores an entry', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      final notifier = HistoryNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final entry = notifier.state.value!.first;
      await notifier.deleteEntry('h1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.value, isEmpty);

      await notifier.reInsertEntry(entry);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.value!.length, 1);
    });

    test('clearAll sets state to empty data', () async {
      await WatchProgress.saveHistory(
        'h1', 'Movie 1', 'c.png', 'http://u', 'vod',
      );
      final notifier = HistoryNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await notifier.clearAll();
      expect(notifier.state.hasValue, true);
      expect(notifier.state.value, isEmpty);
    });
  });

  group('watchProgressProvider', () {
    test('provides a FutureProvider that resolves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read the provider — it returns a future
      final result = await container.read(watchProgressProvider.future);
      expect(result, isA<Map<String, double>>());
      expect(result, isEmpty);
    });
  });

  group('continueWatchingProvider', () {
    test('provides a FutureProvider that resolves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result, isEmpty);
    });
  });
}
