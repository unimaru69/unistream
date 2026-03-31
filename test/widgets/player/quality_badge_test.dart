import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/widgets/quality_badge.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('QualityBadge', () {
    testWidgets('renders quality text', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: 'HD', bitrate: ''),
      ));
      await tester.pumpAndSettle();

      expect(find.text('HD'), findsOneWidget);
    });

    testWidgets('shows nothing when qualityBadge is empty', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: '', bitrate: ''),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('displays bitrate alongside quality', (tester) async {
      await tester.pumpWidget(testApp(
        const QualityBadge(qualityBadge: 'FHD', bitrate: '8 Mbps'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('FHD'), findsOneWidget);
      expect(find.text('8 Mbps'), findsOneWidget);
    });
  });
}
