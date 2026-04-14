import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/account_info.dart';
import 'package:unistream/providers/auth_provider.dart';
import 'package:unistream/utils/feature_access.dart';
import 'package:unistream/widgets/premium_gate.dart';

import '../helpers/test_wrapper.dart';

void main() {
  group('PremiumGate', () {
    testWidgets('shows child when user is premium', (tester) async {
      await tester.pumpWidget(testApp(
        const PremiumGate(
          feature: Feature.collections,
          child: Text('Unlocked'),
        ),
        overrides: [
          authProvider.overrideWith((_) {
            final n = AuthNotifier();
            // We need to set the state directly
            return n;
          }),
        ],
      ));
      // Default state is loading/unauthenticated, so locked
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('shows locked widget when user is basic', (tester) async {
      final notifier = AuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (_, ref, __) {
                  // Force state
                  return const PremiumGate(
                    feature: Feature.collections,
                    child: Text('Unlocked'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default state has no accountInfo → locked
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Unlocked'), findsNothing);
    });

    testWidgets('shows custom lockedChild when provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => AuthNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const PremiumGate(
                feature: Feature.miniPlayer,
                lockedChild: Text('Custom Locked'),
                child: Text('Unlocked'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Locked'), findsOneWidget);
      expect(find.text('Unlocked'), findsNothing);
    });

    testWidgets('tapping default locked widget shows dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => AuthNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const PremiumGate(
                feature: Feature.collections,
                child: Text('Unlocked'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('checkPremiumAccess', () {
    test('returns true for premium account', () {
      final account = AccountInfo(
        id: 'test',
        trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        subscriptionTier: 'premium',
      );
      expect(FeatureAccess.canUse(Feature.collections, account), isTrue);
    });

    test('returns false for basic account', () {
      final account = AccountInfo(
        id: 'test',
        trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        subscriptionTier: 'basic',
      );
      expect(FeatureAccess.canUse(Feature.collections, account), isFalse);
    });
  });
}
