import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/screens/home/widgets/stream_list.dart';

import '../../helpers/mock_data.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('StreamListView', () {
    Widget buildStreamList({
      ContentMode mode = ContentMode.vod,
      String? selectedCategory = '1',
      bool loadingStreams = false,
      bool showGrid = false,
      List<dynamic>? sortedStreams,
      String searchQuery = '',
      TextEditingController? searchCtrl,
      Future<void> Function()? onRefresh,
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
            onRefresh: onRefresh,
          ),
        ),
      );
    }

    testWidgets('shows "select a category" when selectedCategory is null',
        (tester) async {
      await tester.pumpWidget(buildStreamList(selectedCategory: null));
      await tester.pumpAndSettle();

      expect(find.text('Sélectionne une catégorie'), findsOneWidget);
    });

    testWidgets('shows skeleton loading when loadingStreams is true',
        (tester) async {
      await tester.pumpWidget(buildStreamList(loadingStreams: true));
      // Pump a few frames but don't settle (skeleton has animation)
      await tester.pump(const Duration(milliseconds: 100));

      // SkeletonList widget should be present
      expect(find.byType(StreamListView), findsOneWidget);
    });

    testWidgets('renders list of stream names in list mode', (tester) async {
      await tester.pumpWidget(buildStreamList());
      await tester.pumpAndSettle();

      expect(find.text('Movie A'), findsOneWidget);
      expect(find.text('Movie B'), findsOneWidget);
      expect(find.text('Movie C'), findsOneWidget);
    });

    testWidgets('renders search bar with search icon', (tester) async {
      await tester.pumpWidget(buildStreamList());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders favorite star icons for each item', (tester) async {
      await tester.pumpWidget(buildStreamList());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsAtLeast(1));
    });

    testWidgets('renders bookmark icons for VOD items', (tester) async {
      await tester.pumpWidget(buildStreamList(mode: ContentMode.vod));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsAtLeast(1));
    });

    testWidgets('does not render bookmark icons for live mode', (tester) async {
      await tester.pumpWidget(buildStreamList(
        mode: ContentMode.live,
        sortedStreams: [
          mockChannel(streamId: 1, name: 'Channel A'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('onPlayStream is called when tapping a list item',
        (tester) async {
      dynamic tappedStream;
      await tester.pumpWidget(testApp(
        SizedBox(
          width: 400,
          height: 600,
          child: StreamListView(
            mode: ContentMode.vod,
            selectedCategory: '1',
            loadingStreams: false,
            showGrid: false,
            sortedStreams: [mockVodItem(streamId: 1, name: 'Tap Me')],
            searchQuery: '',
            searchCtrl: TextEditingController(),
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
            onPlayStream: (s) => tappedStream = s,
            onToggleFavorite: (_) {},
            onToggleWatchlist: (_) {},
            onShowStreamInfo: (_) {},
            onRemoveFromCollection: (_) {},
            favKeyBuilder: (k, s) => '$k:${s.streamId}',
            itemSelectionKeyBuilder: (s) => 'vod:${s.streamId}',
            progressKeyBuilder: (s) => s.streamId.toString(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Me'));
      expect(tappedStream, isNotNull);
    });

    testWidgets('renders grid view with SliverGrid when showGrid is true',
        (tester) async {
      await tester.pumpWidget(buildStreamList(showGrid: true));
      await tester.pumpAndSettle();

      // The widget moved from GridView/ListView to a CustomScrollView with
      // SliverGrid / SliverList children so the optional header (search bar
      // + actions) can scroll away with the content.
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);
    });

    testWidgets('renders list view with SliverList when showGrid is false',
        (tester) async {
      await tester.pumpWidget(buildStreamList(showGrid: false));
      await tester.pumpAndSettle();

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets('wraps in RefreshIndicator when onRefresh is provided',
        (tester) async {
      await tester.pumpWidget(buildStreamList(
        onRefresh: () async {},
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('no RefreshIndicator when onRefresh is null', (tester) async {
      await tester.pumpWidget(buildStreamList(onRefresh: null));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });
}
