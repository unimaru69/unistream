import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/home/home_screen.dart';

import 'app_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMockHttpClient();
    // Also keep dart:io override for any direct HttpClient usage
    HttpOverrides.global = setupMockHttp();
  });

  tearDown(() {
    teardownMockHttpClient();
    HttpOverrides.global = null;
  });

  group('Favorites Flow', () {
    testWidgets('Home screen shows categories from mock API', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Categories from mock data should be visible in sidebar
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
    });

    testWidgets('Selecting a category loads channels', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Tap the "News" category in the sidebar
      await tester.tap(find.text('News'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Channels for this category should now be visible
      expect(find.text('CNN Live'), findsOneWidget);
      expect(find.text('BBC News'), findsOneWidget);
    });

    testWidgets('Star icon toggles favorite on a channel', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Select category to load channels
      await tester.tap(find.text('News'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Find star_border icons (unfavorited channels)
      final stars = find.byIcon(Icons.star_border);
      expect(stars, findsWidgets);

      // Tap the first star to favorite
      await tester.tap(stars.first);
      await tester.pumpAndSettle();

      // Should now have at least one filled star
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('Favorite persists after switching content mode and back',
        (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Select category and favorite a channel
      await tester.tap(find.text('News'));
      await pumpFor(tester, const Duration(seconds: 2));

      final stars = find.byIcon(Icons.star_border);
      await tester.tap(stars.first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsWidgets);

      // Switch to VOD and back to Live
      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Live'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Re-select the category
      await tester.tap(find.text('News'));
      await pumpFor(tester, const Duration(seconds: 2));

      // The favorite should still be there
      expect(find.byIcon(Icons.star), findsWidgets);
    });
  });
}
