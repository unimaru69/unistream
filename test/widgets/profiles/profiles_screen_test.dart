import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/profile.dart';
import 'package:unistream/providers/config_provider.dart';
import 'package:unistream/screens/profiles/profiles_screen.dart';

/// A fake ConfigNotifier that exposes controlled state.
class FakeConfigNotifier extends StateNotifier<ConfigState>
    implements ConfigNotifier {
  FakeConfigNotifier(super.state);

  @override
  void refresh() {}
  @override
  Future<void> switchProfile(String profileId) async {}
  @override
  Future<void> addProfile(Profile profile) async {}
  @override
  Future<void> updateProfile(Profile profile) async {}
  @override
  Future<void> deleteProfile(String id) async {}
  @override
  Future<void> save(String server, String user, String pass) async {}
}

void main() {
  group('ProfilesScreen', () {
    final testProfiles = [
      Profile(
        id: '1',
        name: 'Serveur Principal',
        serverUrl: 'http://server1.com',
        username: 'user1',
        password: 'pass1',
      ),
      Profile(
        id: '2',
        name: 'Serveur Backup',
        serverUrl: 'http://server2.com',
        username: 'user2',
        password: 'pass2',
      ),
    ];

    Widget buildProfiles({
      List<Profile>? profiles,
      String activeProfileId = '1',
    }) {
      final profs = profiles ?? testProfiles;
      final configState = ConfigState(
        profiles: profs,
        activeProfileId: activeProfileId,
        isConfigured: true,
      );
      return ProviderScope(
        overrides: [
          configProvider
              .overrideWith((_) => FakeConfigNotifier(configState)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: ProfilesScreen(
            onAdd: (_) async {},
            onUpdate: (_) async {},
            onDelete: (_) async {},
            onSwitch: (_) async {},
          ),
        ),
      );
    }

    testWidgets('renders title Profils', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.text('Profils'), findsOneWidget);
    });

    testWidgets('renders add button in app bar', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders profile names', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.text('Serveur Principal'), findsOneWidget);
      expect(find.text('Serveur Backup'), findsOneWidget);
    });

    testWidgets('renders server URLs', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.text('http://server1.com'), findsOneWidget);
      expect(find.text('http://server2.com'), findsOneWidget);
    });

    testWidgets('active profile shows avatar emoji', (tester) async {
      await tester.pumpWidget(buildProfiles(activeProfileId: '1'));
      await tester.pumpAndSettle();

      // Both profiles should show their avatar emoji (default '👤')
      expect(find.text('👤'), findsNWidgets(2));
    });

    testWidgets('inactive profile shows Activer button', (tester) async {
      await tester.pumpWidget(buildProfiles(activeProfileId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Activer'), findsOneWidget);
    });

    testWidgets('renders edit icons for all profiles', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsNWidgets(2));
    });

    testWidgets('renders delete icons when multiple profiles', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('renders back button', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('profile cards use Card widget', (tester) async {
      await tester.pumpWidget(buildProfiles());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
    });
  });
}
