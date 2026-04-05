import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/widgets/channel_number_osd.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('ChannelNumberOsd', () {
    testWidgets('renders the digit string', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '42')]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders multi-digit strings', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '123')]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('123'), findsOneWidget);
    });

    testWidgets('is positioned top-left via Positioned widget', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '7')]),
      ));
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.top, 16);
      expect(positioned.left, 16);
    });

    testWidgets('uses bold text style', (tester) async {
      await tester.pumpWidget(testApp(
        const Stack(children: [ChannelNumberOsd(digits: '99')]),
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('99'));
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.fontSize, 32);
    });
  });
}
