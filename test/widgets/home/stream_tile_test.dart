import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/content_mode.dart';
import 'package:unistream/models/vod_item.dart';
import 'package:unistream/screens/home/widgets/stream_tile.dart';

import '../../helpers/mock_data.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('StreamGridTile', () {
    Widget buildTile({
      VodItem? item,
      VoidCallback? onTap,
      double? progress,
      bool isFav = false,
      bool isInWatchlist = false,
    }) {
      return testApp(
        SizedBox(
          width: 150,
          height: 250,
          child: StreamGridTile(
            stream: item ?? mockVodItem(name: 'Mon Film'),
            mode: ContentMode.vod,
            progress: progress,
            isFav: isFav,
            isInWatchlist: isInWatchlist,
            isInCollection: false,
            selectionMode: false,
            isSelected: false,
            onTap: onTap ?? () {},
            onToggleFavorite: () {},
            onToggleWatchlist: () {},
            onSecondaryTap: (_) {},
          ),
        ),
      );
    }

    testWidgets('renders stream name', (tester) async {
      await tester.pumpWidget(buildTile());
      await tester.pumpAndSettle();

      expect(find.text('Mon Film'), findsOneWidget);
    });

    testWidgets('tap triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTile(onTap: () => tapped = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon Film'));
      expect(tapped, isTrue);
    });

    testWidgets('shows progress bar when progress is set', (tester) async {
      await tester.pumpWidget(buildTile(progress: 0.5));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows filled star when isFav is true', (tester) async {
      await tester.pumpWidget(buildTile(isFav: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });
  });
}
