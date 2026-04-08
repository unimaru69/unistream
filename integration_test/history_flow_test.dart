import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/history_screen.dart';

import 'app_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMockHttpClient();
    HttpOverrides.global = setupMockHttp();
  });

  tearDown(() {
    teardownMockHttpClient();
    HttpOverrides.global = null;
  });

  group('History Flow', () {
    testWidgets('History screen renders with empty state', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const HistoryScreen()));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('History screen back button pops navigator', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                child: const Text('Open History'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate to history
      await tester.tap(find.text('Open History'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      // Go back
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Open History'), findsOneWidget);
    });
  });
}
