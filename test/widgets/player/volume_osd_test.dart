import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/widgets/volume_osd.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('VolumeOsd', () {
    testWidgets('renders with volume level text', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 75)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('shows volume_off icon at volume 0', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 0)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows volume_mute icon when volume < 50 (but > 0)', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 30)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.volume_mute), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('shows volume_down icon when volume >= 50 and < 120', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 100)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.volume_down), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows volume_up icon when volume >= 120', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 150)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.text('150%'), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator reflects normalized volume', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 100)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // volume 100 / 200 = 0.5
      expect(indicator.value, closeTo(0.5, 0.001));
    });

    testWidgets('clamps volume to 200 max in display', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 250)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      // Should clamp to 200
      expect(find.text('200%'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(1.0, 0.001));
    });

    testWidgets('contains a Semantics widget for accessibility', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [VolumeOsd(volume: 60)]),
      ));
      await tester.pump(const Duration(milliseconds: 250));

      // The VolumeOsd wraps its content in a Semantics widget
      expect(find.byType(Semantics), findsWidgets);
      expect(find.text('60%'), findsOneWidget);
    });
  });
}
