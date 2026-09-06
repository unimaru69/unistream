import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/core/form_factor.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/screens/auth/auth_screen.dart';
import 'package:unistream/screens/auth/forgot_password_page.dart';
import 'package:unistream/screens/auth/magic_link_page.dart';
import 'package:unistream/screens/onboarding_screen.dart';
import 'package:unistream/utils/theme.dart';

/// TV focus smoke suite — every screen of the sign-in → onboarding path
/// is pumped in forced-TV mode and must satisfy the leanback contract:
///
/// 1. after settling, a REAL node holds primary focus (not a bare
///    FocusScope) — the D-pad has an anchor and something is visibly
///    highlighted;
/// 2. that landing focus is never a text field itself (which would pop
///    the fullscreen IME on arrival);
/// 3. key transitions hand focus over explicitly (onboarding welcome →
///    config form).
///
/// Grow this suite with every new screen added to the TV path — a screen
/// missing from here is a screen nobody verified with a remote.
void main() {
  setUp(() => FormFactorInfo.debugIsAndroidTv = true);
  tearDown(() => FormFactorInfo.debugIsAndroidTv = false);

  /// 720p TV viewport — the default 800×600 test window overflows some
  /// auth-screen rows, which fails tests before focus is even asserted.
  Future<void> useTvViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(
          theme: darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: home,
        ),
      );

  /// The leanback landing contract (points 1 + 2 above).
  void expectSeededNonFieldFocus() {
    final pf = FocusManager.instance.primaryFocus;
    expect(pf, isNotNull, reason: 'nothing holds focus — dead D-pad');
    expect(pf, isNot(isA<FocusScopeNode>()),
        reason: 'only a bare scope holds focus — dead D-pad');
    final isField =
        pf!.context?.findAncestorStateOfType<EditableTextState>() != null;
    expect(isField, isFalse,
        reason: 'a text field grabbed the landing focus — IME would pop');
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // TvFocusScope seeds via chained post-frame callbacks.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  testWidgets('AuthScreen (login) seeds a real, non-field focus',
      (tester) async {
    await useTvViewport(tester);
    await tester.pumpWidget(app(const AuthScreen()));
    await settle(tester);
    expectSeededNonFieldFocus();
  });

  testWidgets('MagicLinkPage seeds a real, non-field focus', (tester) async {
    await useTvViewport(tester);
    await tester.pumpWidget(app(const MagicLinkPage()));
    await settle(tester);
    expectSeededNonFieldFocus();
  });

  testWidgets('ForgotPasswordPage seeds a real, non-field focus',
      (tester) async {
    await useTvViewport(tester);
    await tester.pumpWidget(app(const ForgotPasswordPage()));
    await settle(tester);
    expectSeededNonFieldFocus();
  });

  testWidgets(
      'Onboarding: welcome seeds focus, Enter opens config, focus lands on '
      'the server guard (not the field)', (tester) async {
    await useTvViewport(tester);
    await tester.pumpWidget(app(const OnboardingScreen()));
    await settle(tester);
    expectSeededNonFieldFocus();

    // Activate the focused "Configurer" button with the remote.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Page transition (400 ms) + explicit focus handoff.
    await settle(tester);

    // Config form visible…
    expect(find.text('Nom d\'utilisateur'), findsOneWidget);
    // …and the D-pad landed on the server field's guard.
    expectSeededNonFieldFocus();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'serverGuard',
        reason: 'page transition must hand focus to the server guard');
  });

  testWidgets(
      'Onboarding config: arrows traverse the form without entering fields',
      (tester) async {
    await useTvViewport(tester);
    await tester.pumpWidget(app(const OnboardingScreen()));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    // Walk the whole form downwards; at every stop the focus must be a
    // real non-field node (guards + buttons), i.e. no IME pop anywhere.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expectSeededNonFieldFocus();
    }
  });
}
