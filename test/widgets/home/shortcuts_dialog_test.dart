import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/home/widgets/shortcuts_dialog.dart';

void main() {
  group('showShortcutsDialog', () {
    Widget buildApp() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showShortcutsDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    testWidgets('dialog opens and shows title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Raccourcis clavier'), findsOneWidget);
    });

    testWidgets('dialog shows keyboard shortcut keys', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Global shortcuts
      expect(find.text('Cmd+Q'), findsOneWidget);
      expect(find.text('Cmd+F'), findsOneWidget);
      expect(find.text('Cmd+,'), findsOneWidget);

      // Player shortcuts
      expect(find.text('Espace'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
    });

    testWidgets('dialog shows section headers', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Section header for player
      expect(find.textContaining('Lecteur'), findsAtLeast(1));
    });

    testWidgets('dialog has Fermer button that closes it', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Fermer'), findsOneWidget);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Raccourcis clavier'), findsNothing);
    });
  });
}
