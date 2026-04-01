import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/screens/home/widgets/stream_list.dart';

import '../../helpers/mock_data.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('StreamListView pagination', () {
    Widget buildStreamList({
      ContentMode mode = ContentMode.vod,
      String? selectedCategory = '1',
      bool loadingStreams = false,
      bool showGrid = false,
      List<dynamic>? sortedStreams,
      String searchQuery = '',
      TextEditingController? searchCtrl,
      bool hasMore = false,
      int totalCount = 0,
      bool isLoadingMore = false,
      VoidCallback? onLoadMore,
    }) {
      final streams = sortedStreams ??
          [
            mockVodItem(streamId: 1, name: 'Movie A'),
            mockVodItem(streamId: 2, name: 'Movie B'),
            mockVodItem(streamId: 3, name: 'Movie C'),
          ];
      return testApp(
        SizedBox(
          width: 400,
          height: 600,
          child: StreamListView(
            mode: mode,
            selectedCategory: selectedCategory,
            loadingStreams: loadingStreams,
            showGrid: showGrid,
            sortedStreams: streams,
            searchQuery: searchQuery,
            searchCtrl: searchCtrl ?? TextEditingController(),
            onSearchChanged: (_) {},
            onClearSearch: () {},
            progress: {},
            favKeys: {},
            wlKeys: {},
            selectionMode: false,
            selectedItems: {},
            onEnterSelectionMode: () {},
            onExitSelectionMode: () {},
            onSelectAll: () {},
            onCreateCollectionFromSelected: () {},
            onToggleSelection: (_) {},
            activeCollectionId: null,
            onPlayStream: (_) {},
            onToggleFavorite: (_) {},
            onToggleWatchlist: (_) {},
            onShowStreamInfo: (_) {},
            onRemoveFromCollection: (_) {},
            favKeyBuilder: (modeKey, stream) => '$modeKey:${stream.streamId}',
            itemSelectionKeyBuilder: (stream) => 'vod:${stream.streamId}',
            progressKeyBuilder: (stream) => stream.streamId.toString(),
            hasMore: hasMore,
            totalCount: totalCount,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore,
          ),
        ),
      );
    }

    testWidgets('shows item count when totalCount > 0', (tester) async {
      final streams = List.generate(
        5,
        (i) => mockVodItem(streamId: i + 1, name: 'Movie ${i + 1}'),
      );
      await tester.pumpWidget(buildStreamList(
        sortedStreams: streams,
        totalCount: 100,
        hasMore: true,
      ));
      // Use pump instead of pumpAndSettle since CircularProgressIndicator animates forever
      await tester.pump(const Duration(milliseconds: 100));

      // Should show "5 / 100"
      expect(find.text('5 / 100'), findsOneWidget);
    });

    testWidgets('does not show item count when totalCount is 0', (tester) async {
      await tester.pumpWidget(buildStreamList(totalCount: 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('shows loading indicator when hasMore is true in list view', (tester) async {
      final streams = List.generate(
        3,
        (i) => mockVodItem(streamId: i + 1, name: 'Movie ${i + 1}'),
      );
      await tester.pumpWidget(buildStreamList(
        sortedStreams: streams,
        hasMore: true,
        totalCount: 100,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // The CircularProgressIndicator should exist in the list
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not show loading indicator when hasMore is false', (tester) async {
      await tester.pumpWidget(buildStreamList(
        hasMore: false,
        totalCount: 3,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('formats large totalCount with commas', (tester) async {
      final streams = List.generate(
        5,
        (i) => mockVodItem(streamId: i + 1, name: 'Movie ${i + 1}'),
      );
      await tester.pumpWidget(buildStreamList(
        sortedStreams: streams,
        totalCount: 10234,
        hasMore: true,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('5 / 10,234'), findsOneWidget);
    });

    testWidgets('calls onLoadMore when scrolled near bottom', (tester) async {
      int loadMoreCount = 0;
      // Create enough items to make the list scrollable
      final streams = List.generate(
        20,
        (i) => mockVodItem(streamId: i + 1, name: 'Movie ${i + 1}'),
      );
      await tester.pumpWidget(buildStreamList(
        sortedStreams: streams,
        hasMore: true,
        totalCount: 100,
        onLoadMore: () => loadMoreCount++,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to the bottom
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump(const Duration(milliseconds: 100));

      expect(loadMoreCount, greaterThan(0));
    });

    testWidgets('renders existing items correctly with pagination params', (tester) async {
      await tester.pumpWidget(buildStreamList(
        totalCount: 50,
        hasMore: true,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Movie A'), findsOneWidget);
      expect(find.text('Movie B'), findsOneWidget);
      expect(find.text('Movie C'), findsOneWidget);
    });
  });

  group('StreamListView static helpers', () {
    test('getName extracts name from VodItem', () {
      final vod = mockVodItem(name: 'Test Name');
      expect(StreamListView.getName(vod), 'Test Name');
    });

    test('getName extracts name from Channel', () {
      final ch = mockChannel(name: 'Channel Name');
      expect(StreamListView.getName(ch), 'Channel Name');
    });

    test('getName extracts name from SeriesItem', () {
      final s = mockSeriesItem(name: 'Series Name');
      expect(StreamListView.getName(s), 'Series Name');
    });

    test('getName extracts name from Map', () {
      expect(StreamListView.getName({'name': 'Map Name'}), 'Map Name');
    });

    test('getStreamId works for all types', () {
      expect(StreamListView.getStreamId(mockChannel(streamId: 42)), '42');
      expect(StreamListView.getStreamId(mockVodItem(streamId: 7)), '7');
      expect(StreamListView.getStreamId(mockSeriesItem(seriesId: 99)), '99');
      expect(StreamListView.getStreamId({'stream_id': 5}), '5');
      expect(StreamListView.getStreamId({'series_id': 10}), '10');
    });
  });
}
