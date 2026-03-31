import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildOnboarding() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const OnboardingScreen(),
        ),
      );
    }

    testWidgets('first page shows welcome text', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('Bienvenue sur UniStream'), findsOneWidget);
    });

    testWidgets('first page shows Commencer button', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('first page shows logo image', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('tapping Commencer advances to config page', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // Page 2 should show form fields
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Connexion'), findsOneWidget);
    });
  });
}
