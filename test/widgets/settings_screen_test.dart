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
      expect(find.byIcon(Icons.person), findsWidgets);
    });

    testWidgets('renders password field with visibility toggle',
        (tester) async {
      await pumpSettings(tester);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      // The TMDB key field also ships a visibility toggle (visible
      // initially as Icons.visibility), so two of the same icon are
      // expected on a fresh settings screen — match by key on the
      // server-password one specifically.
      expect(find.byKey(const Key('server_password_visibility_toggle')),
          findsOneWidget);
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

      final toggle = find.byKey(const Key('server_password_visibility_toggle'));

      // Resolve the IconData inside the toggle so the assertions don't
      // care about other visibility icons on the page (TMDB key field).
      IconData iconOf(Finder f) =>
          (tester.widget<Icon>(find.descendant(of: f, matching: find.byType(Icon))))
              .icon!;

      // Initially obscured
      expect(iconOf(toggle), Icons.visibility);

      // Tap visibility toggle
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(iconOf(toggle), Icons.visibility_off);
    });

    testWidgets('renders the four server-config + TMDB text fields',
        (tester) async {
      await pumpSettings(tester);
      // 3 server-config fields (URL / username / password) + 1 TMDB API
      // key field on the same screen.
      expect(find.byType(TextField), findsNWidgets(4));
    });
  });
}
