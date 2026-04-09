import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/screens/player/widgets/channel_list_overlay.dart';
import 'package:unistream/screens/player/widgets/channel_number_osd.dart';
import 'package:unistream/screens/player/widgets/quality_badge.dart';

import '../../helpers/test_wrapper.dart';

/// Helper to create a Channel with minimal required fields.
Channel _channel({
  required int id,
  required String name,
  dynamic num,
}) {
  return Channel(streamId: id, name: name, num: num);
}

void main() {
  // ─── QualityBadge ───────────────────────────────────────────────────

  group('QualityBadge', () {
    testWidgets('empty qualityBadge renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: '', bitrate: ''),
      ));
      await tester.pumpAndSettle();

      // SizedBox.shrink is returned — no Tooltip in the tree
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('shows quality text when qualityBadge is set', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: 'HD', bitrate: ''),
      ));
      await tester.pumpAndSettle();

      expect(find.text('HD'), findsOneWidget);
    });

    testWidgets('shows bitrate alongside quality', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: 'FHD', bitrate: '8 Mbps'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('FHD'), findsOneWidget);
      expect(find.text('8 Mbps'), findsOneWidget);
    });

    testWidgets('4K badge uses amber color', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: '4K', bitrate: ''),
      ));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.amber);
    });
  });

  // ─── ChannelNumberOsd ───────────────────────────────────────────────

  group('ChannelNumberOsd', () {
    testWidgets('renders single digit', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '5')]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders multi-digit string', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '456')]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('456'), findsOneWidget);
    });

    testWidgets('uses bold 32px text style', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '1')]),
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('1'));
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.fontSize, 32);
    });
  });

  // ─── ChannelListOverlay ─────────────────────────────────────────────

  group('ChannelListOverlay', () {
    final channels = [
      _channel(id: 1, name: 'TF1', num: 1),
      _channel(id: 2, name: 'France 2', num: 2),
      _channel(id: 3, name: 'France 3', num: 3),
      _channel(id: 4, name: 'Canal+', num: 4),
      _channel(id: 5, name: 'France 5', num: 5),
    ];

    Widget buildOverlay({
      int currentIndex = 0,
      void Function(int)? onSelect,
      VoidCallback? onClose,
      List<Channel>? channelList,
    }) {
      return testApp(
        SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            children: [
              ChannelListOverlay(
                channels: channelList ?? channels,
                currentIndex: currentIndex,
                onSelect: onSelect ?? (_) {},
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders all channel names', (tester) async {
      await tester.pumpWidget(buildOverlay());
      await tester.pumpAndSettle();

      expect(find.text('TF1'), findsOneWidget);
      expect(find.text('France 2'), findsOneWidget);
      expect(find.text('France 3'), findsOneWidget);
      expect(find.text('Canal+'), findsOneWidget);
      expect(find.text('France 5'), findsOneWidget);
    });

    testWidgets('shows channel numbers', (tester) async {
      await tester.pumpWidget(buildOverlay());
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('highlights current channel with play icon', (tester) async {
      await tester.pumpWidget(buildOverlay(currentIndex: 2));
      await tester.pumpAndSettle();

      // The current channel gets a play_arrow icon
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('current channel name is bold', (tester) async {
      await tester.pumpWidget(buildOverlay(currentIndex: 1));
      await tester.pumpAndSettle();

      // Find all Text widgets with channel names
      final france2Text = tester.widget<Text>(find.text('France 2'));
      expect(france2Text.style?.fontWeight, FontWeight.bold);

      // Non-current channel should not be bold
      final tf1Text = tester.widget<Text>(find.text('TF1'));
      expect(tf1Text.style?.fontWeight, FontWeight.normal);
    });

    testWidgets('tapping a channel calls onSelect with correct index', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(buildOverlay(
        onSelect: (i) => selectedIndex = i,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Canal+'));
      expect(selectedIndex, 3);
    });

    testWidgets('displays channel count', (tester) async {
      await tester.pumpWidget(buildOverlay());
      await tester.pumpAndSettle();

      // The overlay shows "X chaines" via loc.nombreChaines
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('handles channels without num', (tester) async {
      final noNumChannels = [
        _channel(id: 10, name: 'Stream A', num: null),
        _channel(id: 11, name: 'Stream B', num: null),
      ];

      await tester.pumpWidget(buildOverlay(channelList: noNumChannels));
      await tester.pumpAndSettle();

      expect(find.text('Stream A'), findsOneWidget);
      expect(find.text('Stream B'), findsOneWidget);
    });
  });
}
