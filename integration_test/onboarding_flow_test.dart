import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/splash_screen.dart';
import 'package:unistream/screens/onboarding_screen.dart';
import 'package:unistream/screens/home/home_screen.dart';

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

  group('Onboarding Flow', () {
    testWidgets('Splash screen navigates to onboarding when no profile is saved',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const SplashScreen()));

      // Splash screen should display the UniStream title
      expect(find.text('UniStream'), findsOneWidget);

      // Wait for the splash animation (1s) + delay (500ms) + navigation
      await pumpFor(tester, const Duration(seconds: 3));

      // After splash completes, we should be on the onboarding screen
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('Splash screen navigates to home when profile is configured',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SplashScreen()));

      expect(find.text('UniStream'), findsOneWidget);

      // Wait for splash animation + navigation
      await pumpFor(tester, const Duration(seconds: 3));

      // Should land on HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Onboarding: welcome page shows Get Started button',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Welcome page should be visible
      expect(find.text('Welcome to UniStream'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('Onboarding: tap Get Started navigates to config page',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Tap "Get started" button
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Config page should now be visible with form fields
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Onboarding: form validation requires all fields',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Go to config page
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Tap Sign In without filling fields
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('All fields are required'), findsWidgets);
    });

    testWidgets(
        'Onboarding: fill credentials and connect successfully leads to home',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Go to config page
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Fill in form fields
      // Find TextFormFields -- server URL, username, password
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'http://test.server.com:8080');
      await tester.enterText(textFields.at(1), 'testuser');
      await tester.enterText(textFields.at(2), 'testpass');

      // Tap Sign In
      await tester.tap(find.text('Sign in'));

      // Wait for the auth call + success animation + navigation to home
      await pumpFor(tester, const Duration(seconds: 4));

      // Should show success page first, then navigate to HomeScreen
      // The success page shows "Your server is configured!" briefly
      // After 1.5s delay, it navigates to HomeScreen
      // By this point, we should be on Home
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Onboarding: invalid URL shows validation error',
        (tester) async {
      setupAppConfigEmpty();

      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Go to config page
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);

      // Enter invalid URL (no scheme)
      await tester.enterText(textFields.at(0), 'not-a-url');
      await tester.enterText(textFields.at(1), 'user');
      await tester.enterText(textFields.at(2), 'pass');

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Should show URL validation error
      expect(find.text('URL invalide'), findsOneWidget);
    });
  });
}
