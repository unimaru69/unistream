import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/profile.dart';
import 'package:unistream/screens/profiles/profile_selector_screen.dart';

void main() {
  final testProfiles = [
    Profile(
      id: '1',
      name: 'Papa',
      serverUrl: 'http://server.com',
      username: 'user1',
      password: 'pass1',
      avatar: '👨',
    ),
    Profile(
      id: '2',
      name: 'Maman',
      serverUrl: 'http://server.com',
      username: 'user2',
      password: 'pass2',
      avatar: '👩',
    ),
    Profile(
      id: '3',
      name: 'Enfant',
      serverUrl: 'http://server.com',
      username: 'user3',
      password: 'pass3',
      avatar: '🧒',
      pinHash: 'somehash',
    ),
  ];

  Widget buildApp({String activeProfileId = '1'}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: ProfileSelectorScreen(
        profiles: testProfiles,
        activeProfileId: activeProfileId,
      ),
    );
  }

  group('ProfileSelectorScreen', () {
    testWidgets('renders "Qui regarde ?" title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Qui regarde ?'), findsOneWidget);
    });

    testWidgets('renders all profile names', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Papa'), findsOneWidget);
      expect(find.text('Maman'), findsOneWidget);
      expect(find.text('Enfant'), findsOneWidget);
    });

    testWidgets('renders avatar emojis', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('👨'), findsOneWidget);
      expect(find.text('👩'), findsOneWidget);
      expect(find.text('🧒'), findsOneWidget);
    });

    testWidgets('shows lock icon for PIN-protected profiles', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      // Only the "Enfant" profile has a PIN
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('tapping non-PIN profile pops with selected profile', (tester) async {
      Profile? selected;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Builder(builder: (context) => ElevatedButton(
          onPressed: () async {
            selected = await Navigator.push<Profile>(context,
                MaterialPageRoute(builder: (_) => ProfileSelectorScreen(
                  profiles: testProfiles, activeProfileId: '1',
                )));
          },
          child: const Text('Open'),
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap "Maman" (no PIN)
      await tester.tap(find.text('Maman'));
      await tester.pumpAndSettle();

      expect(selected?.id, '2');
      expect(selected?.name, 'Maman');
    });

    testWidgets('tapping PIN-protected profile shows PIN dialog', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enfant'));
      await tester.pumpAndSettle();

      // PIN dialog should appear
      expect(find.text('Entrez le PIN du profil'), findsOneWidget);
    });
  });
}
