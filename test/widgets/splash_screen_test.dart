import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:unistream/screens/splash_screen.dart';

import '../helpers/test_wrapper.dart';

/// Helper to build the splash wrapped in a Navigator so pushReplacement works.
Widget _splashApp() {
  return testApp(
    Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const SplashScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Inject a mock HTTP client that always succeeds instantly
    splashHttpClient = http_testing.MockClient((_) async => http.Response('', 200));
  });

  tearDown(() {
    splashHttpClient = null;
  });

  group('SplashScreen', () {
    testWidgets('shows UniStream text', (tester) async {
      await tester.pumpWidget(_splashApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('UniStream'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('shows logo image', (tester) async {
      await tester.pumpWidget(_splashApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('animation progresses after pumping frames', (tester) async {
      await tester.pumpWidget(_splashApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ScaleTransition), findsAtLeast(1));
      expect(find.text('UniStream'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('shows loading indicator after animation completes', (tester) async {
      await tester.pumpWidget(_splashApp());

      // Complete the animation (1000ms) and trigger _startLoadingSequence
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(); // Let setState land

      // Loading indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Settle all remaining timers (navigation etc.)
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('shows loading config status text after animation', (tester) async {
      await tester.pumpWidget(_splashApp());

      // Complete the animation
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();

      // Should show configuration loading message (fr locale)
      expect(find.textContaining('Chargement'), findsOneWidget);

      // Settle all remaining timers
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('navigates away after full loading sequence', (tester) async {
      await tester.pumpWidget(_splashApp());

      // Complete animation + all loading delays
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // SplashScreen should no longer be on screen (navigated away)
      expect(find.text('UniStream'), findsNothing);
    });

    testWidgets('has gradient background', (tester) async {
      await tester.pumpWidget(_splashApp());
      await tester.pump(const Duration(milliseconds: 100));

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.decoration, isNotNull);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('does not show loading before animation completes', (tester) async {
      await tester.pumpWidget(_splashApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Should NOT show loading indicator yet
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}
