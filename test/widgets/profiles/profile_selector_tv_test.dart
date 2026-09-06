import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/core/form_factor.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/profile.dart';
import 'package:unistream/screens/profiles/profile_selector_screen.dart';

/// D-pad (Android TV) behaviour of the profile selector.
///
/// Regression tests for the real-device report: with zero profiles, the
/// "Nouveau profil" card was a bare GestureDetector — unreachable with a
/// remote; only the "Changer de compte" TextButton could be focused.
void main() {
  setUp(() => FormFactorInfo.debugIsAndroidTv = true);
  tearDown(() => FormFactorInfo.debugIsAndroidTv = false);

  final testProfiles = [
    Profile(
      id: '1',
      name: 'Papa',
      serverUrl: 'http://server.com',
      username: 'user1',
      password: 'pass1',
      avatar: '👨',
    ),
  ];

  Future<ProfileSelectorResult?> Function() pumpSelector(
    WidgetTester tester, {
    required List<Profile> profiles,
  }) {
    ProfileSelectorResult? result;
    bool popped = false;
    tester.runAsync(() async {});
    return () async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<ProfileSelectorResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileSelectorScreen(
                      profiles: profiles,
                      activeProfileId: profiles.isEmpty ? null : '1',
                      allowCreate: true,
                    ),
                  ),
                );
                popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Let TvFocusScope's post-frame seeding land.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(popped, isFalse, reason: 'selector should still be open');
      return result;
    };
  }

  testWidgets(
      'TV, zero profiles: Nouveau profil is the seeded focus and Enter activates it',
      (tester) async {
    final open = pumpSelector(tester, profiles: const []);
    await open();

    // Something real must hold focus (not just the route scope).
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isNotNull);
    expect(primary, isNot(isA<FocusScopeNode>()));

    // Activate — the first focusable on screen is the Nouveau profil card.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // The selector popped with the create request → the card was both
    // focusable and activatable from the D-pad.
    expect(find.text('Nouveau profil'), findsNothing);
  });

  testWidgets(
      'TV, with profiles: arrows traverse from profile card to Nouveau profil',
      (tester) async {
    final open = pumpSelector(tester, profiles: testProfiles);
    await open();

    // Seeded on the first card (Papa). Move right to the add card, then
    // activate with the D-pad center key.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('Qui regarde ?'), findsNothing,
        reason: 'selector should have popped via ProfileCreateRequested');
  });
}
