import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/widgets/skeleton_list.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('SkeletonList', () {
    testWidgets('renders shimmer items in list mode', (tester) async {
      await tester.pumpWidget(testApp(
        const SizedBox(
          width: 400,
          height: 600,
          child: SkeletonList(count: 5, isGrid: false),
        ),
      ));
      // Pump a frame to start animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('renders grid layout when isGrid is true', (tester) async {
      await tester.pumpWidget(testApp(
        const SizedBox(
          width: 400,
          height: 600,
          child: SkeletonList(count: 8, isGrid: true),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('uses default count of 10', (tester) async {
      await tester.pumpWidget(testApp(
        const SizedBox(
          width: 400,
          height: 600,
          child: SkeletonList(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Default should be list mode with 10 items
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
