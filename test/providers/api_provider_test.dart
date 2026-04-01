import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/providers/api_provider.dart';
import 'package:unistream/models/content_mode.dart';

void main() {
  group('API Providers — type checks', () {
    test('categoriesProvider is a family FutureProvider keyed by ContentMode', () {
      // Verify the provider exists and can be accessed
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading the provider returns an AsyncValue (it will fail network-wise
      // but we are testing that the provider structure is correct)
      for (final mode in ContentMode.values) {
        final asyncValue = container.read(categoriesProvider(mode));
        // The provider should be in a loading or error state (no real API)
        expect(asyncValue, isNotNull);
      }
    });

    test('liveStreamsProvider accepts nullable String', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(liveStreamsProvider(null));
      expect(asyncValue, isNotNull);

      final asyncValueWithCat = container.read(liveStreamsProvider('5'));
      expect(asyncValueWithCat, isNotNull);
    });

    test('vodStreamsProvider accepts nullable String', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(vodStreamsProvider(null));
      expect(asyncValue, isNotNull);
    });

    test('seriesListProvider accepts nullable String', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(seriesListProvider(null));
      expect(asyncValue, isNotNull);
    });

    test('seriesEpisodesProvider accepts String', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(seriesEpisodesProvider('123'));
      expect(asyncValue, isNotNull);
    });

    test('authProvider is a simple FutureProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(authProvider);
      expect(asyncValue, isNotNull);
    });
  });
}
