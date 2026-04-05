import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/profiles/profile_dialog.dart';

void main() {
  group('ProfileDialog', () {
    Widget buildDialog() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const Scaffold(body: ProfileDialog()),
      );
    }

    testWidgets('renders new profile title when no profile given',
        (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Nouveau profil'), findsOneWidget);
    });

    testWidgets('renders four form fields', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('renders name field with label', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Nom du profil'), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    });

    testWidgets('renders server URL field', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('URL du serveur'), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
    });

    testWidgets('renders username and password fields', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Nom d\'utilisateur'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('renders cancel and submit buttons', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Tester et ajouter'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('form validation shows error on empty name', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Fill server URL (valid) but leave name empty
      // Enter text in server field
      final serverField = find.byType(TextFormField).at(1);
      await tester.enterText(serverField, 'http://test.com');

      // Enter username
      final userField = find.byType(TextFormField).at(2);
      await tester.enterText(userField, 'user');

      // Enter password
      final passField = find.byType(TextFormField).at(3);
      await tester.enterText(passField, 'pass');

      // Tap submit
      await tester.tap(find.text('Tester et ajouter'));
      await tester.pumpAndSettle();

      // Validation error should appear
      expect(find.text('Tous les champs sont requis'), findsAtLeast(1));
    });

    testWidgets('form validation shows error on empty server URL',
        (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Fill name but leave server empty
      final nameField = find.byType(TextFormField).at(0);
      await tester.enterText(nameField, 'My Profile');

      // Enter username
      final userField = find.byType(TextFormField).at(2);
      await tester.enterText(userField, 'user');

      // Enter password
      final passField = find.byType(TextFormField).at(3);
      await tester.enterText(passField, 'pass');

      // Tap submit
      await tester.tap(find.text('Tester et ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Tous les champs sont requis'), findsAtLeast(1));
    });

    testWidgets('form validation shows error on invalid URL', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Fill all fields with invalid URL
      await tester.enterText(find.byType(TextFormField).at(0), 'My Profile');
      await tester.enterText(find.byType(TextFormField).at(1), 'not-a-url');
      await tester.enterText(find.byType(TextFormField).at(2), 'user');
      await tester.enterText(find.byType(TextFormField).at(3), 'pass');

      await tester.tap(find.text('Tester et ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('URL invalide (ex: http://...)'), findsOneWidget);
    });
  });
}
