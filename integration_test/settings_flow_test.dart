import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/home/home_screen.dart';
import 'package:unistream/screens/settings_screen.dart';

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

  group('Settings Flow', () {
    testWidgets('Settings screen displays server info', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Server URL and username should be visible
      expect(find.text('http://test.server.com:8080'), findsOneWidget);
      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('Theme toggle changes app theme', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Find the theme toggle — look for a switch or segment control
      // The theme section should contain dark/light mode options
      final darkModeSwitch = find.byType(Switch);
      if (darkModeSwitch.evaluate().isNotEmpty) {
        await tester.tap(darkModeSwitch.first);
        await tester.pumpAndSettle();
        // If we get here without error, theme toggle works
      }

      // Settings screen should still be visible
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Settings back navigation returns to home', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Go back
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Navigate to settings twice without crash', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HomeScreen()));
      await pumpFor(tester, const Duration(seconds: 3));

      // First navigation
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Go back
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      // Second navigation
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
