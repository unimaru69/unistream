import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/account_info.dart';

void main() {
  group('AccountInfo', () {
    test('reads the account row', () {
      final info = AccountInfo.fromJson({
        'id': 'user-1',
        'email': 'someone@example.invalid',
        'created_at': '2026-04-10T08:00:00Z',
      });
      expect(info.id, 'user-1');
      expect(info.email, 'someone@example.invalid');
      expect(info.createdAt, DateTime.utc(2026, 4, 10, 8));
    });

    test('ignores the legacy trial and subscription columns', () {
      // user_accounts still has these columns; the app must not depend on
      // them, whatever they contain.
      final info = AccountInfo.fromJson({
        'id': 'user-1',
        'trial_started_at': '2020-01-01T00:00:00Z',
        'subscription_tier': 'trial',
        'subscription_expires_at': '2020-02-01T00:00:00Z',
        'cross_platform_license': false,
      });
      expect(info.id, 'user-1');
      expect(info.email, '');
      expect(info.createdAt, isNull);
    });
  });
}
