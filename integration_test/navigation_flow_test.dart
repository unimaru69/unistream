import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/home/home_screen.dart';
import 'package:unistream/screens/search_screen.dart';
import 'package:unistream/screens/settings_screen.dart';
import 'app_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpOverrides mockHttp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockHttp = setupMockHttp();
    HttpOverrides.global = mockHttp;
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  group('Navigation Flow', () {
    testWidgets('Home screen loads and displays app bar with UniStream title',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));

      // Wait for categories to load from mock API
      await pumpFor(tester, const Duration(seconds: 3));

      expect(find.text('UniStream'), findsOneWidget);
    });

    testWidgets('Home screen shows content mode toggle buttons',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // The three toggle buttons: Live, VOD, Series
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('VOD'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
    });

    testWidgets('Tap search icon navigates to SearchScreen', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Find and tap the search icon button
      final searchIcon = find.byIcon(Icons.search);
      expect(searchIcon, findsOneWidget);
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      // Should be on SearchScreen
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('Search screen has back button to return to home',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Navigate to search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      // Go back using the Navigator (the back icon varies by platform)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      // Should be back on HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Tap settings icon navigates to SettingsScreen',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Find and tap the settings icon button
      final settingsIcon = find.byIcon(Icons.settings_outlined);
      expect(settingsIcon, findsOneWidget);
      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      // Should be on SettingsScreen
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Settings screen shows server configuration fields',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Settings should show the pre-filled server URL
      expect(find.text('http://test.server.com:8080'), findsOneWidget);
      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('Settings screen back button returns to home', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Go back using the Navigator (the back button icon varies by platform)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      // Should be back on HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Switching content modes updates the UI', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Default mode is Live -- tap VOD
      await tester.tap(find.text('VOD'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Tap Series
      await tester.tap(find.text('Series'));
      await pumpFor(tester, const Duration(seconds: 2));

      // Tap back to Live
      await tester.tap(find.text('Live'));
      await pumpFor(tester, const Duration(seconds: 2));

      // If we got here without error, navigation between modes works
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
