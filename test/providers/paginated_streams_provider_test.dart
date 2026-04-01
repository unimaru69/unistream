import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/providers/paginated_streams_provider.dart';
import 'package:unistream/models/content_mode.dart';

void main() {
  group('PaginatedStreamsNotifier', () {
    late ProviderContainer container;
    late PaginatedStreamsNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(paginatedStreamsProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems, isEmpty);
      expect(state.hasMore, false);
      expect(state.totalCount, 0);
      expect(state.isLoadingMore, false);
    });

    test('reset shows first page', () {
      final items = List.generate(120, (i) => {'id': i, 'name': 'Item $i'});
      notifier.reset(items, pageSize: 50);

      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 50);
      expect(state.hasMore, true);
      expect(state.totalCount, 120);
      expect(state.isLoadingMore, false);
    });

    test('reset with fewer items than page size shows all', () {
      final items = List.generate(10, (i) => {'id': i});
      notifier.reset(items, pageSize: 50);

      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 10);
      expect(state.hasMore, false);
      expect(state.totalCount, 10);
    });

    test('reset with empty list', () {
      notifier.reset([], pageSize: 50);

      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems, isEmpty);
      expect(state.hasMore, false);
      expect(state.totalCount, 0);
    });

    test('loadMore appends next page', () {
      final items = List.generate(120, (i) => {'id': i});
      notifier.reset(items, pageSize: 50);

      notifier.loadMore();
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 100);
      expect(state.hasMore, true);
      expect(state.totalCount, 120);
    });

    test('loadMore loads remaining items on last page', () {
      final items = List.generate(120, (i) => {'id': i});
      notifier.reset(items, pageSize: 50);

      notifier.loadMore(); // 100
      notifier.loadMore(); // 120
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 120);
      expect(state.hasMore, false);
    });

    test('loadMore does nothing when no more items', () {
      final items = List.generate(30, (i) => {'id': i});
      notifier.reset(items, pageSize: 50);

      notifier.loadMore(); // Should do nothing
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 30);
      expect(state.hasMore, false);
    });

    test('reset clears previous state', () {
      final items1 = List.generate(100, (i) => {'id': i, 'set': 1});
      notifier.reset(items1, pageSize: 50);
      notifier.loadMore();
      expect(container.read(paginatedStreamsProvider).visibleItems.length, 100);

      final items2 = List.generate(20, (i) => {'id': i, 'set': 2});
      notifier.reset(items2, pageSize: 50);
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 20);
      expect(state.hasMore, false);
      expect(state.totalCount, 20);
      expect((state.visibleItems.first as Map)['set'], 2);
    });

    test('multiple loadMore calls reach the end', () {
      final items = List.generate(175, (i) => i);
      notifier.reset(items, pageSize: 50);

      notifier.loadMore(); // 100
      notifier.loadMore(); // 150
      notifier.loadMore(); // 175
      final state = container.read(paginatedStreamsProvider);
      expect(state.visibleItems.length, 175);
      expect(state.hasMore, false);

      // Extra loadMore should be a no-op
      notifier.loadMore();
      expect(container.read(paginatedStreamsProvider).visibleItems.length, 175);
    });
  });

  group('pageSizeForMode', () {
    test('live returns 50', () {
      expect(pageSizeForMode(ContentMode.live), 50);
    });

    test('vod returns 30', () {
      expect(pageSizeForMode(ContentMode.vod), 30);
    });

    test('series returns 30', () {
      expect(pageSizeForMode(ContentMode.series), 30);
    });
  });
}
