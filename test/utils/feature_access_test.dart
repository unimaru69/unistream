import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/account_info.dart';
import 'package:unistream/utils/feature_access.dart';

void main() {
  AccountInfo makeTrial({int daysAgo = 0}) => AccountInfo(
        id: 'test',
        trialStartedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
        subscriptionTier: 'trial',
      );

  AccountInfo makeBasic({DateTime? expiresAt}) => AccountInfo(
        id: 'test',
        trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        subscriptionTier: 'basic',
        subscriptionExpiresAt: expiresAt,
      );

  AccountInfo makePremium({DateTime? expiresAt}) => AccountInfo(
        id: 'test',
        trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        subscriptionTier: 'premium',
        subscriptionExpiresAt: expiresAt,
      );

  AccountInfo makeExpiredBasic() => makeBasic(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );

  AccountInfo makeExpiredPremium() => makePremium(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );

  group('FeatureAccess.canUse', () {
    const premiumFeatures = Feature.values;

    group('null account', () {
      test('denies all features', () {
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, null), isFalse, reason: f.name);
        }
      });
    });

    group('active trial (full Premium)', () {
      test('allows all premium features', () {
        final account = makeTrial(daysAgo: 0);
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isTrue, reason: f.name);
        }
      });
    });

    group('trial day 13 (still active)', () {
      test('allows all premium features', () {
        final account = makeTrial(daysAgo: 13);
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isTrue, reason: f.name);
        }
      });
    });

    group('expired trial', () {
      test('denies all features', () {
        final account = makeTrial(daysAgo: 15);
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isFalse, reason: f.name);
        }
      });
    });

    group('active basic subscription', () {
      test('denies all premium features', () {
        final account = makeBasic();
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isFalse, reason: f.name);
        }
      });
    });

    group('active premium subscription', () {
      test('allows all features', () {
        final account = makePremium();
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isTrue, reason: f.name);
        }
      });
    });

    group('premium with future expiry', () {
      test('allows all features', () {
        final account = makePremium(
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
        );
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isTrue, reason: f.name);
        }
      });
    });

    group('expired basic subscription', () {
      test('denies all features', () {
        final account = makeExpiredBasic();
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isFalse, reason: f.name);
        }
      });
    });

    group('expired premium subscription', () {
      test('denies all features', () {
        final account = makeExpiredPremium();
        for (final f in premiumFeatures) {
          expect(FeatureAccess.canUse(f, account), isFalse, reason: f.name);
        }
      });
    });
  });

  group('FeatureAccess.maxProfiles', () {
    test('null account = 1', () {
      expect(FeatureAccess.maxProfiles(null), 1);
    });

    test('active trial = 10 (full Premium)', () {
      expect(FeatureAccess.maxProfiles(makeTrial()), 10);
    });

    test('basic = 1', () {
      expect(FeatureAccess.maxProfiles(makeBasic()), 1);
    });

    test('premium = 10', () {
      expect(FeatureAccess.maxProfiles(makePremium()), 10);
    });

    test('expired premium = 1', () {
      expect(FeatureAccess.maxProfiles(makeExpiredPremium()), 1);
    });
  });
}
