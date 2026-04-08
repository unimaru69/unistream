import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/home/home_screen.dart';
import 'package:unistream/screens/vod/vod_detail_screen.dart';
import 'package:unistream/screens/series_detail_screen.dart';

import 'app_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpOverrides mockHttp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMockHttpClient();
    mockHttp = setupMockHttp();
    HttpOverrides.global = mockHttp;
  });

  tearDown(() {
    teardownMockHttpClient();
    HttpOverrides.global = null;
  });

  group('VOD Flow', () {
    testWidgets('Switch to VOD mode shows VOD categories', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Switch to VOD mode
      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Should see VOD categories in sidebar
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Comedy'), findsOneWidget);
    });

    testWidgets('Select VOD category loads VOD items', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Select a VOD category
      await tester.tap(find.text('Action'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Should see the VOD item
      expect(find.text('Action Movie 1'), findsOneWidget);
    });

    testWidgets('Tap VOD item navigates to VodDetailScreen', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));

      await tester.tap(find.text('Action'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Tap the VOD item
      await tester.tap(find.text('Action Movie 1'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Should be on VodDetailScreen
      expect(find.byType(VodDetailScreen), findsOneWidget);
    });

    testWidgets('VOD detail back button returns to home', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Action'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Action Movie 1'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.byType(VodDetailScreen), findsOneWidget);

      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Series Flow', () {
    testWidgets('Switch to Series mode shows series categories',
        (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('Series'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Should see series categories
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('Thriller'), findsOneWidget);
    });

    testWidgets('Select series category and tap item opens detail',
        (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('Series'));
      await pumpFor(tester, const Duration(seconds: 2));

      await tester.tap(find.text('Drama'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Tap series item
      await tester.tap(find.text('Drama Series'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Should be on SeriesDetailScreen
      expect(find.byType(SeriesDetailScreen), findsOneWidget);
    });

    testWidgets('Series detail back button returns to home', (tester) async {
      setupAppConfigWithProfile();

      setWideWindowSize(tester);
      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.text('Series'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Drama'));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Drama Series'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.byType(SeriesDetailScreen), findsOneWidget);

      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
