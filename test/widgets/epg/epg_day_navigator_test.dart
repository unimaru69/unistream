import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/epg/widgets/epg_day_navigator.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('EpgDayNavigator', () {
    final today = DateTime(2026, 4, 1);

    Widget buildNavigator({
      bool canGoPrev = true,
      bool canGoNext = true,
      VoidCallback? onPrev,
      VoidCallback? onNext,
    }) {
      return testApp(
        EpgDayNavigator(
          dayStart: today,
          canGoPrev: canGoPrev,
          canGoNext: canGoNext,
          onPrev: onPrev ?? () {},
          onNext: onNext ?? () {},
          formatDay: (d) => '${d.day}/${d.month}/${d.year}',
        ),
      );
    }

    testWidgets('renders day label with formatted date', (tester) async {
      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      expect(find.text('1/4/2026'), findsOneWidget);
    });

    testWidgets('renders Hier and Demain buttons', (tester) async {
      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Demain'), findsOneWidget);
    });

    testWidgets('renders chevron icons', (tester) async {
      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping Hier calls onPrev', (tester) async {
      var prevCalled = false;
      await tester.pumpWidget(buildNavigator(onPrev: () => prevCalled = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hier'));
      expect(prevCalled, isTrue);
    });

    testWidgets('tapping Demain calls onNext', (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(buildNavigator(onNext: () => nextCalled = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demain'));
      expect(nextCalled, isTrue);
    });

    testWidgets('Hier button is disabled when canGoPrev is false',
        (tester) async {
      var prevCalled = false;
      await tester.pumpWidget(
          buildNavigator(canGoPrev: false, onPrev: () => prevCalled = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hier'));
      expect(prevCalled, isFalse);
    });

    testWidgets('Demain button is disabled when canGoNext is false',
        (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(
          buildNavigator(canGoNext: false, onNext: () => nextCalled = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demain'));
      expect(nextCalled, isFalse);
    });
  });
}
