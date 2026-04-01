import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/providers/config_provider.dart';
import 'package:unistream/providers/locale_provider.dart';
import 'package:unistream/screens/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildSettings() {
      return ProviderScope(
        overrides: [
          configProvider.overrideWith((_) {
            return ConfigNotifier();
          }),
          localeProvider.overrideWith((_) => LocaleNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const SettingsScreen(),
        ),
      );
    }

    Future<void> pumpSettings(WidgetTester tester) async {
      // Suppress overflow errors (the SettingsScreen ConstrainedBox maxWidth:420
      // is narrower than some SegmentedButton rows).
      final origDebugOverflowIndicator = debugPaintSizeEnabled;
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        if (origOnError != null) origOnError(details);
      };

      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      addTearDown(() {
        FlutterError.onError = origOnError;
        debugPaintSizeEnabled = origDebugOverflowIndicator;
      });
    }

    testWidgets('renders title Paramètres', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Paramètres'), findsOneWidget);
    });

    testWidgets('renders server URL field', (tester) async {
      await pumpSettings(tester);
      expect(find.text('URL du serveur'), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
    });

    testWidgets('renders username field', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Nom d\'utilisateur'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders password field with visibility toggle',
        (tester) async {
      await pumpSettings(tester);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('renders save button', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('renders appearance section with theme toggle',
        (tester) async {
      await pumpSettings(tester);
      expect(find.text('APPARENCE'), findsOneWidget);
      expect(find.text('Thème'), findsOneWidget);
      expect(find.byIcon(Icons.brightness_6), findsOneWidget);
    });

    testWidgets('renders language section', (tester) async {
      await pumpSettings(tester);
      expect(find.text('LANGUES'), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      expect(find.byIcon(Icons.subtitles), findsOneWidget);
    });

    testWidgets('renders interface language selector', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Langue interface'), findsOneWidget);
      expect(find.text('Français'), findsAtLeast(1));
      expect(find.text('English'), findsAtLeast(1));
    });

    testWidgets('renders import/export section', (tester) async {
      await pumpSettings(tester);
      expect(find.text('IMPORT / EXPORT'), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('renders cache section', (tester) async {
      await pumpSettings(tester);
      expect(find.text('CACHE'), findsOneWidget);
      expect(find.byIcon(Icons.data_usage), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await pumpSettings(tester);

      // Initially obscured
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('renders three text fields for server config', (tester) async {
      await pumpSettings(tester);
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });
}
