import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/profile.dart';

void main() {
  group('Profile', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'id': 'abc-123',
        'name': 'My Profile',
        'serverUrl': 'http://example.com',
        'username': 'user1',
        'password': 'pass123',
      };
      final profile = Profile.fromJson(json);
      expect(profile.id, 'abc-123');
      expect(profile.name, 'My Profile');
      expect(profile.serverUrl, 'http://example.com');
      expect(profile.username, 'user1');
      expect(profile.password, 'pass123');
    });

    test('toJson produces correct map', () {
      final profile = Profile(
        id: 'def-456',
        name: 'Test',
        serverUrl: 'http://test.com',
        username: 'testuser',
        password: 'testpass',
      );
      final json = profile.toJson();
      expect(json['id'], 'def-456');
      expect(json['name'], 'Test');
      expect(json['serverUrl'], 'http://test.com');
      expect(json['username'], 'testuser');
      expect(json['password'], 'testpass');
    });

    test('toJson roundtrip produces equal values', () {
      final original = Profile(
        id: 'round-1',
        name: 'Roundtrip',
        serverUrl: 'http://rt.com',
        username: 'rt_user',
        password: 'rt_pass',
      );
      final json = original.toJson();
      final restored = Profile.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
    });

    test('fromJson throws on missing required field', () {
      final json = {
        'id': 'x',
        'name': 'x',
        // missing serverUrl, username, password
      };
      expect(() => Profile.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('mutable fields can be updated', () {
      final profile = Profile(
        id: 'mut-1',
        name: 'Original',
        serverUrl: 'http://old.com',
        username: 'old',
        password: 'old',
      );
      profile.name = 'Updated';
      profile.serverUrl = 'http://new.com';
      profile.username = 'new';
      profile.password = 'new';
      expect(profile.name, 'Updated');
      expect(profile.serverUrl, 'http://new.com');
      expect(profile.username, 'new');
      expect(profile.password, 'new');
    });

    test('fromJson with empty strings', () {
      final json = {
        'id': '',
        'name': '',
        'serverUrl': '',
        'username': '',
        'password': '',
      };
      final profile = Profile.fromJson(json);
      expect(profile.id, '');
      expect(profile.name, '');
      expect(profile.serverUrl, '');
    });
  });
}
