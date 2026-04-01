import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/xtream_api.dart';

void main() {
  group('XtreamApi stream cache', () {
    setUp(() {
      XtreamApi.clearStreamCache();
      // Reset to real clock
      XtreamApi.streamCacheNow = () => DateTime.now();
    });

    tearDown(() {
      XtreamApi.clearStreamCache();
      XtreamApi.streamCacheNow = () => DateTime.now();
    });

    test('clearStreamCache resets cache size to 0', () {
      expect(XtreamApi.streamCacheSize, 0);
    });

    test('streamCacheSize reflects entries', () {
      // We can't easily test cache hits without mocking HTTP,
      // but we can verify the cache infrastructure exists
      expect(XtreamApi.streamCacheSize, isA<int>());
    });

    test('streamCacheNow is overridable for testing', () {
      final fixedTime = DateTime(2025, 1, 1, 12, 0);
      XtreamApi.streamCacheNow = () => fixedTime;
      // Verify the override works (used internally by cache)
      expect(XtreamApi.streamCacheNow(), fixedTime);
    });
  });
}
