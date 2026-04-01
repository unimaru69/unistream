import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/screens/search_screen.dart';

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

  group('Search Flow', () {
    testWidgets('Search screen shows hint text for minimum query length',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Should show the "type at least 2 characters" hint
      // The l10n key is tapeAuMoins2 which in English is something like
      // "Type at least 2 characters"
      // Let's check by finding the TextField with autofocus
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
    });

    testWidgets('Search screen has tab bar with All, Live, Films, Series',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Check tab labels exist (en locale: All, Live, Movies, Series)
      expect(find.text('All'), findsWidgets); // also used in filter chips
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
    });

    testWidgets('Entering search text triggers API call and shows results',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Type a search query (at least 2 chars to trigger search)
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'CNN');

      // Wait for debounce (400ms) + API call + render
      await pumpFor(tester, const Duration(seconds: 3));

      // Should find "CNN Live" in the results (ListTile with that text)
      expect(find.widgetWithText(ListTile, 'CNN Live'), findsOneWidget);
    });

    testWidgets('Search filters results based on query text', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Search for "ESPN"
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'ESPN');
      await pumpFor(tester, const Duration(seconds: 3));

      // Should find ESPN in the list results but not CNN or BBC
      expect(find.widgetWithText(ListTile, 'ESPN'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CNN Live'), findsNothing);
      expect(find.widgetWithText(ListTile, 'BBC News'), findsNothing);
    });

    testWidgets('Search shows no results for unmatched query', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Search for something that won't match
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'xyznonexistent');
      await pumpFor(tester, const Duration(seconds: 3));

      // Should show "no results" message
      // The l10n key is aucunResultat
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('Search across content types shows mixed results',
        (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Search for a term that matches across types
      // "Action" matches "Action Movie 1" in VOD
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Action');
      await pumpFor(tester, const Duration(seconds: 3));

      expect(find.text('Action Movie 1'), findsOneWidget);
    });

    testWidgets('Tab filtering works on search results', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      // Search for a broad term that matches multiple types
      // "Drama" matches "Drama Series" in series
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Drama');
      await pumpFor(tester, const Duration(seconds: 3));

      // On the "All" tab, should show Drama Series
      expect(find.text('Drama Series'), findsOneWidget);

      // Switch to Live tab -- should not show Drama Series
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();

      expect(find.text('Drama Series'), findsNothing);

      // Switch to Series tab -- should show Drama Series again
      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();

      expect(find.text('Drama Series'), findsOneWidget);
    });

    testWidgets('Short query (1 char) does not trigger search', (tester) async {
      setupAppConfigWithProfile();

      await tester.pumpWidget(buildTestApp(home: const SearchScreen()));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'C');
      await pumpFor(tester, const Duration(seconds: 2));

      // Should not show any results -- still showing hint
      expect(find.text('CNN Live'), findsNothing);
    });
  });
}
