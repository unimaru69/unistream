import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/providers/catalog_refresh_provider.dart';

void main() {
  group('CatalogRefreshInterval.fromSeconds', () {
    test('maps known values', () {
      expect(CatalogRefreshInterval.fromSeconds(0),
          CatalogRefreshInterval.manual);
      expect(CatalogRefreshInterval.fromSeconds(21600),
          CatalogRefreshInterval.sixHours);
      expect(CatalogRefreshInterval.fromSeconds(43200),
          CatalogRefreshInterval.twelveHours);
      expect(CatalogRefreshInterval.fromSeconds(86400),
          CatalogRefreshInterval.daily);
    });

    test('falls back to 6 h when unset or unknown', () {
      expect(CatalogRefreshInterval.fromSeconds(null),
          CatalogRefreshInterval.sixHours);
      // A value written by a future build we don't know about.
      expect(CatalogRefreshInterval.fromSeconds(999),
          CatalogRefreshInterval.sixHours);
    });
  });

  group('CatalogRefreshState.isStale', () {
    test('never refreshed is stale', () {
      const state = CatalogRefreshState(
          lastRefresh: null, interval: CatalogRefreshInterval.sixHours);
      expect(state.isStale, isTrue);
    });

    test('never stale on manual, even when never refreshed', () {
      const state = CatalogRefreshState(
          lastRefresh: null, interval: CatalogRefreshInterval.manual);
      expect(state.isStale, isFalse);
    });

    test('fresh inside the interval', () {
      final state = CatalogRefreshState(
        lastRefresh: DateTime.now().subtract(const Duration(hours: 5)),
        interval: CatalogRefreshInterval.sixHours,
      );
      expect(state.isStale, isFalse);
    });

    test('stale past the interval', () {
      final state = CatalogRefreshState(
        lastRefresh: DateTime.now().subtract(const Duration(hours: 7)),
        interval: CatalogRefreshInterval.sixHours,
      );
      expect(state.isStale, isTrue);
    });

    test('interval is honoured — 7 h is fresh on the 12 h setting', () {
      final state = CatalogRefreshState(
        lastRefresh: DateTime.now().subtract(const Duration(hours: 7)),
        interval: CatalogRefreshInterval.twelveHours,
      );
      expect(state.isStale, isFalse);
    });
  });
}
