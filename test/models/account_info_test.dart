import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/account_info.dart';

void main() {
  group('AccountInfo', () {
    AccountInfo makeTrial({int daysAgo = 0}) => AccountInfo(
          id: 'test-id',
          email: 'test@example.com',
          trialStartedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
          subscriptionTier: 'trial',
        );

    AccountInfo makePaid(String tier, {DateTime? expiresAt}) => AccountInfo(
          id: 'test-id',
          email: 'test@example.com',
          trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
          subscriptionTier: tier,
          subscriptionExpiresAt: expiresAt,
        );

    group('trial logic', () {
      test('new account has 14 days remaining', () {
        final info = makeTrial(daysAgo: 0);
        expect(info.isTrial, isTrue);
        expect(info.trialDaysRemaining, 14);
        expect(info.isTrialActive, isTrue);
        expect(info.isTrialExpired, isFalse);
        expect(info.hasAccess, isTrue);
      });

      test('7 days into trial has 7 days remaining', () {
        final info = makeTrial(daysAgo: 7);
        expect(info.trialDaysRemaining, 7);
        expect(info.isTrialActive, isTrue);
        expect(info.isTrialExpired, isFalse);
      });

      test('day 13 still active', () {
        final info = makeTrial(daysAgo: 13);
        expect(info.trialDaysRemaining, 1);
        expect(info.isTrialActive, isTrue);
      });

      test('day 14 exactly = expired', () {
        final info = makeTrial(daysAgo: 14);
        expect(info.trialDaysRemaining, 0);
        expect(info.isTrialActive, isFalse);
        expect(info.isTrialExpired, isTrue);
        expect(info.hasAccess, isFalse);
      });

      test('day 30 = expired, 0 remaining', () {
        final info = makeTrial(daysAgo: 30);
        expect(info.trialDaysRemaining, 0);
        expect(info.isTrialExpired, isTrue);
      });
    });

    group('subscription logic', () {
      test('basic subscription without expiry = active', () {
        final info = makePaid('basic');
        expect(info.isTrial, isFalse);
        expect(info.hasActiveSubscription, isTrue);
        expect(info.isBasicOrAbove, isTrue);
        expect(info.isPremium, isFalse);
        expect(info.hasAccess, isTrue);
      });

      test('premium subscription without expiry = active', () {
        final info = makePaid('premium');
        expect(info.hasActiveSubscription, isTrue);
        expect(info.isPremium, isTrue);
        expect(info.isBasicOrAbove, isTrue);
      });

      test('subscription with future expiry = active', () {
        final info = makePaid('premium',
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)));
        expect(info.hasActiveSubscription, isTrue);
        expect(info.hasAccess, isTrue);
      });

      test('subscription with past expiry = expired', () {
        final info = makePaid('premium',
            expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)));
        expect(info.hasActiveSubscription, isFalse);
        expect(info.hasAccess, isFalse);
      });

      test('trial does not count as basic or above', () {
        final info = makeTrial();
        expect(info.isBasicOrAbove, isFalse);
        expect(info.isPremium, isFalse);
      });
    });

    group('cross-platform license', () {
      test('default is false', () {
        final info = makeTrial();
        expect(info.crossPlatformLicense, isFalse);
      });

      test('can be set to true', () {
        final info = AccountInfo(
          id: 'test-id',
          email: 'test@example.com',
          trialStartedAt: DateTime.now().toUtc(),
          crossPlatformLicense: true,
        );
        expect(info.crossPlatformLicense, isTrue);
      });
    });

    group('JSON serialization', () {
      test('fromJson round-trip', () {
        final now = DateTime.now().toUtc();
        final info = AccountInfo(
          id: 'abc-123',
          email: 'user@test.com',
          trialStartedAt: now,
          subscriptionTier: 'premium',
          subscriptionExpiresAt: now.add(const Duration(days: 365)),
          crossPlatformLicense: true,
        );
        final json = info.toJson();
        final restored = AccountInfo.fromJson(json);
        expect(restored.id, 'abc-123');
        expect(restored.email, 'user@test.com');
        expect(restored.subscriptionTier, 'premium');
        expect(restored.crossPlatformLicense, isTrue);
        expect(restored.subscriptionExpiresAt, isNotNull);
      });

      test('fromJson with snake_case keys', () {
        final info = AccountInfo.fromJson({
          'id': 'test-id',
          'email': 'test@example.com',
          'trial_started_at': '2026-04-01T00:00:00.000Z',
          'subscription_tier': 'basic',
          'cross_platform_license': false,
        });
        expect(info.subscriptionTier, 'basic');
        expect(info.trialStartedAt.year, 2026);
      });

      test('fromJson with defaults', () {
        final info = AccountInfo.fromJson({
          'id': 'test-id',
          'trial_started_at': '2026-04-10T00:00:00.000Z',
        });
        expect(info.email, '');
        expect(info.subscriptionTier, 'trial');
        expect(info.crossPlatformLicense, isFalse);
        expect(info.subscriptionExpiresAt, isNull);
      });
    });
  });
}
