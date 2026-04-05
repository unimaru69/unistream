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

    test('default avatar is person emoji', () {
      final profile = Profile(id: '1', name: 'Test', serverUrl: 'http://x.com',
          username: 'u', password: 'p');
      expect(profile.avatar, '👤');
    });

    test('hasPin returns false by default', () {
      final profile = Profile(id: '1', name: 'Test', serverUrl: 'http://x.com',
          username: 'u', password: 'p');
      expect(profile.hasPin, false);
    });

    test('hasPin returns true when pinHash is set', () {
      final profile = Profile(id: '1', name: 'Test', serverUrl: 'http://x.com',
          username: 'u', password: 'p', pinHash: 'abc123');
      expect(profile.hasPin, true);
    });

    test('avatar and pinHash roundtrip via JSON', () {
      final original = Profile(id: '1', name: 'Kid', serverUrl: 'http://x.com',
          username: 'u', password: 'p', avatar: '🧒', pinHash: 'hash123');
      final json = original.toJson();
      expect(json['avatar'], '🧒');
      expect(json['pinHash'], 'hash123');
      final restored = Profile.fromJson(json);
      expect(restored.avatar, '🧒');
      expect(restored.pinHash, 'hash123');
      expect(restored.hasPin, true);
    });

    test('fromJson without avatar defaults to person emoji', () {
      final json = {
        'id': '1', 'name': 'Old', 'serverUrl': 'http://x.com',
        'username': 'u', 'password': 'p',
      };
      final profile = Profile.fromJson(json);
      expect(profile.avatar, '👤');
      expect(profile.pinHash, null);
      expect(profile.hasPin, false);
    });

    test('profileAvatars list is non-empty', () {
      expect(profileAvatars, isNotEmpty);
      expect(profileAvatars.length, 24);
    });
  });
}
