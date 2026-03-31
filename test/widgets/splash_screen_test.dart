import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/splash_screen.dart';

import '../helpers/test_wrapper.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('shows UniStream text', (tester) async {
      await tester.pumpWidget(testApp(const SplashScreen()));
      // Pump a few frames for animation to start
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UniStream'), findsOneWidget);
    });

    testWidgets('shows logo image', (tester) async {
      await tester.pumpWidget(testApp(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('animation progresses after pumping frames', (tester) async {
      await tester.pumpWidget(testApp(const SplashScreen()));

      // Initially pump, animation should be running
      await tester.pump(const Duration(milliseconds: 500));

      // The ScaleTransition from SplashScreen should be present
      expect(find.byType(ScaleTransition), findsAtLeast(1));
      // UniStream text should still be visible after animation progress
      expect(find.text('UniStream'), findsOneWidget);
    });
  });
}
