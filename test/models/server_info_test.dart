import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/server_info.dart';

void main() {
  group('UserInfo', () {
    test('fromJson with auth = 1', () {
      final json = {'auth': 1};
      final user = UserInfo.fromJson(json);
      expect(user.auth, 1);
    });

    test('fromJson with missing auth uses default 0', () {
      final json = <String, dynamic>{};
      final user = UserInfo.fromJson(json);
      expect(user.auth, 0);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = UserInfo(auth: 1);
      final json = original.toJson();
      final restored = UserInfo.fromJson(json);
      expect(restored, original);
    });

    test('auth accepts string (dynamic field)', () {
      final json = {'auth': '1'};
      final user = UserInfo.fromJson(json);
      expect(user.auth, '1');
    });
  });

  group('UserInfoX extension', () {
    test('isAuthenticated true when auth is 1', () {
      final user = UserInfo(auth: 1);
      expect(user.isAuthenticated, true);
    });

    test('isAuthenticated true when auth is string "1"', () {
      final user = UserInfo(auth: '1');
      expect(user.isAuthenticated, true);
    });

    test('isAuthenticated false when auth is 0', () {
      final user = UserInfo(auth: 0);
      expect(user.isAuthenticated, false);
    });

    test('isAuthenticated false when auth is string "0"', () {
      final user = UserInfo(auth: '0');
      expect(user.isAuthenticated, false);
    });
  });

  group('ServerDetails', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'time_now': '2024-06-15 12:30:00',
        'timestamp_now': 1718451000,
      };
      final details = ServerDetails.fromJson(json);
      expect(details.timeNow, '2024-06-15 12:30:00');
      expect(details.timestampNow, 1718451000);
    });

    test('fromJson with missing fields', () {
      final json = <String, dynamic>{};
      final details = ServerDetails.fromJson(json);
      expect(details.timeNow, isNull);
      expect(details.timestampNow, isNull);
    });

    test('timestampNow accepts string (dynamic field)', () {
      final json = {'timestamp_now': '1718451000'};
      final details = ServerDetails.fromJson(json);
      expect(details.timestampNow, '1718451000');
    });

    test('toJson roundtrip produces equal objects', () {
      final original = ServerDetails(
        timeNow: '2024-01-01 00:00:00',
        timestampNow: 1704067200,
      );
      final json = original.toJson();
      final restored = ServerDetails.fromJson(json);
      expect(restored, original);
    });
  });

  group('ServerInfo', () {
    test('fromJson with complete nested JSON', () {
      final json = {
        'user_info': {'auth': 1},
        'server_info': {
          'time_now': '2024-06-15 12:30:00',
          'timestamp_now': 1718451000,
        },
      };
      final info = ServerInfo.fromJson(json);
      expect(info.userInfo, isNotNull);
      expect(info.userInfo!.auth, 1);
      expect(info.serverInfo, isNotNull);
      expect(info.serverInfo!.timeNow, '2024-06-15 12:30:00');
    });

    test('fromJson with missing nested objects', () {
      final json = <String, dynamic>{};
      final info = ServerInfo.fromJson(json);
      expect(info.userInfo, isNull);
      expect(info.serverInfo, isNull);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = ServerInfo(
        userInfo: UserInfo(auth: 1),
        serverInfo: ServerDetails(
          timeNow: '2024-01-01 00:00:00',
          timestampNow: 1704067200,
        ),
      );
      // Encode/decode via JSON string to get plain Map<String, dynamic>
      // instead of Freezed model instances in nested fields.
      final rawJson = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final restored = ServerInfo.fromJson(rawJson);
      expect(restored, original);
    });
  });
}
