import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/providers/watch_progress_provider.dart';
import 'package:unistream/screens/search_screen.dart';

void main() {
  group('SearchScreen', () {
    Widget buildSearchScreen() {
      return ProviderScope(
        overrides: [
          watchProgressProvider.overrideWith((ref) => Future.value({})),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const SearchScreen(),
        ),
      );
    }

    testWidgets('renders search text field', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders tab bar with five tabs', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(5));
    });

    testWidgets('renders tab labels: Tout, Live, Films, Séries, Programmes',
        (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Séries'), findsOneWidget);
      expect(find.text('Programmes'), findsOneWidget);
    });

    testWidgets('shows empty state message before typing', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.text('Tape au moins 2 caractères'), findsOneWidget);
    });

    testWidgets('search field has hint text', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.text('Rechercher dans tout le catalogue…'), findsOneWidget);
    });

    testWidgets('typing 1 character still shows minimum chars message',
        (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.text('Tape au moins 2 caractères'), findsOneWidget);
    });

    testWidgets('typing 2+ characters shows loading or results',
        (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'te');
      await tester.pump(const Duration(milliseconds: 100));

      // The minimum chars message should disappear
      expect(find.text('Tape au moins 2 caractères'), findsNothing);
    });

    testWidgets('search field is autofocused', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });
  });
}
