import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/models/app_config.dart';
import 'package:unistream/models/profile.dart';
import 'package:unistream/providers/config_provider.dart';

Profile _profile({
  String id = 'p1',
  String name = 'Test',
  String serverUrl = 'http://server.com',
  String username = 'user',
  String password = 'pass',
}) =>
    Profile(
      id: id,
      name: name,
      serverUrl: serverUrl,
      username: username,
      password: password,
    );

void _resetAppConfig() {
  AppConfig.serverUrl = '';
  AppConfig.username = '';
  AppConfig.password = '';
  AppConfig.activeProfileId = '';
  AppConfig.profiles = [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _resetAppConfig();
  });

  group('ConfigState', () {
    test('default constructor stores provided values', () {
      const state = ConfigState(
        profiles: [],
        activeProfileId: '',
        isConfigured: false,
      );
      expect(state.profiles, isEmpty);
      expect(state.activeProfileId, '');
      expect(state.isConfigured, false);
    });

    test('activeProfile returns matching profile', () {
      final p = _profile(id: 'abc');
      final state = ConfigState(
        profiles: [p],
        activeProfileId: 'abc',
        isConfigured: true,
      );
      expect(state.activeProfile, isNotNull);
      expect(state.activeProfile!.id, 'abc');
      expect(state.activeProfile!.name, 'Test');
    });

    test('activeProfile returns null when no match', () {
      final state = ConfigState(
        profiles: [_profile(id: 'abc')],
        activeProfileId: 'nonexistent',
        isConfigured: true,
      );
      expect(state.activeProfile, isNull);
    });

    test('activeProfile returns null when profiles empty', () {
      const state = ConfigState(
        profiles: [],
        activeProfileId: 'abc',
        isConfigured: false,
      );
      expect(state.activeProfile, isNull);
    });

    test('copyWith overrides specified fields only', () {
      final p1 = _profile(id: 'p1');
      final p2 = _profile(id: 'p2');
      final original = ConfigState(
        profiles: [p1],
        activeProfileId: 'p1',
        isConfigured: true,
      );

      final updated = original.copyWith(
        profiles: [p1, p2],
        activeProfileId: 'p2',
      );
      expect(updated.profiles.length, 2);
      expect(updated.activeProfileId, 'p2');
      expect(updated.isConfigured, true); // unchanged
    });

    test('copyWith with no arguments returns equivalent state', () {
      final original = ConfigState(
        profiles: [_profile()],
        activeProfileId: 'p1',
        isConfigured: true,
      );
      final copy = original.copyWith();
      expect(copy.profiles, original.profiles);
      expect(copy.activeProfileId, original.activeProfileId);
      expect(copy.isConfigured, original.isConfigured);
    });
  });

  group('ConfigNotifier', () {
    test('initial state reflects AppConfig static fields', () {
      AppConfig.profiles = [_profile(id: 'x')];
      AppConfig.activeProfileId = 'x';
      AppConfig.serverUrl = 'http://server.com';
      AppConfig.username = 'user';
      AppConfig.password = 'pass';

      final notifier = ConfigNotifier();
      expect(notifier.state.profiles.length, 1);
      expect(notifier.state.activeProfileId, 'x');
      expect(notifier.state.isConfigured, true);
    });

    test('initial state is not configured when AppConfig is empty', () {
      final notifier = ConfigNotifier();
      expect(notifier.state.profiles, isEmpty);
      expect(notifier.state.activeProfileId, '');
      expect(notifier.state.isConfigured, false);
    });

    test('refresh updates state from AppConfig', () {
      final notifier = ConfigNotifier();
      expect(notifier.state.profiles, isEmpty);

      // Mutate AppConfig externally
      AppConfig.profiles = [_profile(id: 'new')];
      AppConfig.activeProfileId = 'new';
      AppConfig.serverUrl = 'http://new.com';
      AppConfig.username = 'u';
      AppConfig.password = 'p';

      notifier.refresh();
      expect(notifier.state.profiles.length, 1);
      expect(notifier.state.activeProfileId, 'new');
      expect(notifier.state.isConfigured, true);
    });

    test('addProfile adds a profile and refreshes state', () async {
      final notifier = ConfigNotifier();
      final p = _profile(id: 'added');

      await notifier.addProfile(p);

      expect(notifier.state.profiles.length, 1);
      expect(notifier.state.profiles.first.id, 'added');
    });

    test('updateProfile updates existing profile', () async {
      final p = _profile(id: 'up', name: 'Original');
      AppConfig.profiles = [p];
      AppConfig.activeProfileId = 'up';
      AppConfig.serverUrl = p.serverUrl;
      AppConfig.username = p.username;
      AppConfig.password = p.password;

      final notifier = ConfigNotifier();
      expect(notifier.state.profiles.first.name, 'Original');

      final updated = _profile(id: 'up', name: 'Updated');
      await notifier.updateProfile(updated);

      expect(notifier.state.profiles.first.name, 'Updated');
    });

    test('deleteProfile removes profile from state', () async {
      final p = _profile(id: 'del');
      AppConfig.profiles = [p];
      AppConfig.activeProfileId = 'del';

      final notifier = ConfigNotifier();
      expect(notifier.state.profiles.length, 1);

      await notifier.deleteProfile('del');
      expect(notifier.state.profiles, isEmpty);
    });

    test('switchProfile changes activeProfileId', () async {
      final p1 = _profile(id: 'a', serverUrl: 'http://a.com', username: 'ua', password: 'pa');
      final p2 = _profile(id: 'b', serverUrl: 'http://b.com', username: 'ub', password: 'pb');
      AppConfig.profiles = [p1, p2];
      AppConfig.activeProfileId = 'a';
      AppConfig.serverUrl = p1.serverUrl;
      AppConfig.username = p1.username;
      AppConfig.password = p1.password;

      final notifier = ConfigNotifier();
      expect(notifier.state.activeProfileId, 'a');

      await notifier.switchProfile('b');

      expect(notifier.state.activeProfileId, 'b');
      expect(AppConfig.serverUrl, 'http://b.com');
      expect(AppConfig.username, 'ub');
    });

    test('save creates new profile when activeProfileId is empty', () async {
      final notifier = ConfigNotifier();
      expect(notifier.state.profiles, isEmpty);

      await notifier.save('http://new.com', 'newuser', 'newpass');

      expect(notifier.state.profiles.length, 1);
      expect(notifier.state.isConfigured, true);
      expect(AppConfig.serverUrl, 'http://new.com');
      expect(AppConfig.username, 'newuser');
      expect(AppConfig.password, 'newpass');
    });

    test('save updates active profile when one exists', () async {
      final p = _profile(id: 'existing');
      AppConfig.profiles = [p];
      AppConfig.activeProfileId = 'existing';
      AppConfig.serverUrl = p.serverUrl;
      AppConfig.username = p.username;
      AppConfig.password = p.password;

      final notifier = ConfigNotifier();
      await notifier.save('http://updated.com', 'upduser', 'updpass');

      expect(notifier.state.profiles.length, 1);
      expect(AppConfig.serverUrl, 'http://updated.com');
      expect(AppConfig.username, 'upduser');
      expect(AppConfig.password, 'updpass');
    });

    test('save persists profile to SharedPreferences', () async {
      final notifier = ConfigNotifier();
      await notifier.save('http://s.com', 'u', 'p');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.profilesList);
      expect(raw, isNotNull);

      final list = jsonDecode(raw!) as List;
      expect(list.length, 1);
      expect(list.first['serverUrl'], 'http://s.com');
      expect(list.first['username'], 'u');
    });

    test('addProfile persists to SharedPreferences', () async {
      final notifier = ConfigNotifier();
      await notifier.addProfile(_profile(id: 'persist'));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.profilesList);
      expect(raw, isNotNull);

      final list = jsonDecode(raw!) as List;
      expect(list.length, 1);
      expect(list.first['id'], 'persist');
    });

    test('activeProfile on state matches the active profile', () {
      final p = _profile(id: 'act', name: 'Active Profile');
      AppConfig.profiles = [p];
      AppConfig.activeProfileId = 'act';
      AppConfig.serverUrl = p.serverUrl;
      AppConfig.username = p.username;
      AppConfig.password = p.password;

      final notifier = ConfigNotifier();
      final active = notifier.state.activeProfile;
      expect(active, isNotNull);
      expect(active!.name, 'Active Profile');
    });
  });

  group('AppConfig.load', () {
    test('load with profiles_list populates profiles', () async {
      final profilesJson = [
        _profile(id: 'loaded', name: 'Loaded').toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        StorageKeys.profilesList: jsonEncode(profilesJson),
        StorageKeys.activeProfile: 'loaded',
      });
      FlutterSecureStorage.setMockInitialValues({
        'pwd_loaded': 'secret',
      });

      await AppConfig.load();

      expect(AppConfig.profiles.length, 1);
      expect(AppConfig.activeProfileId, 'loaded');
      expect(AppConfig.serverUrl, 'http://server.com');
      expect(AppConfig.username, 'user');
      expect(AppConfig.password, 'secret');
    });

    test('load with no data results in unconfigured state', () async {
      await AppConfig.load();

      expect(AppConfig.profiles, isEmpty);
      expect(AppConfig.isConfigured, false);
    });

    test('load falls back to first profile when active not found', () async {
      final profilesJson = [
        _profile(id: 'first', name: 'First', username: 'u1').toJson(),
        _profile(id: 'second', name: 'Second', username: 'u2').toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        StorageKeys.profilesList: jsonEncode(profilesJson),
        StorageKeys.activeProfile: 'missing',
      });
      FlutterSecureStorage.setMockInitialValues({
        'pwd_first': 'p1',
        'pwd_second': 'p2',
      });

      await AppConfig.load();

      expect(AppConfig.activeProfileId, 'first');
      expect(AppConfig.username, 'u1');
    });

    test('load migrates legacy config keys', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.cfgServer: 'http://legacy.com',
        StorageKeys.cfgUser: 'legacyuser',
        StorageKeys.cfgPass: 'legacypass',
      });
      FlutterSecureStorage.setMockInitialValues({});

      await AppConfig.load();

      expect(AppConfig.profiles.length, 1);
      expect(AppConfig.profiles.first.name, 'Serveur principal');
      expect(AppConfig.serverUrl, 'http://legacy.com');
      expect(AppConfig.username, 'legacyuser');
      expect(AppConfig.password, 'legacypass');
      expect(AppConfig.isConfigured, true);
    });

    test('isConfigured returns false when any field is empty', () {
      AppConfig.serverUrl = 'http://s.com';
      AppConfig.username = '';
      AppConfig.password = 'p';
      expect(AppConfig.isConfigured, false);

      AppConfig.username = 'u';
      AppConfig.password = '';
      expect(AppConfig.isConfigured, false);

      AppConfig.serverUrl = '';
      AppConfig.username = 'u';
      AppConfig.password = 'p';
      expect(AppConfig.isConfigured, false);
    });

    test('isConfigured returns true when all fields set', () {
      AppConfig.serverUrl = 'http://s.com';
      AppConfig.username = 'u';
      AppConfig.password = 'p';
      expect(AppConfig.isConfigured, true);
    });

    test('pfx returns profile-scoped prefix', () {
      AppConfig.activeProfileId = 'myprofile';
      expect(AppConfig.pfx, 'p_myprofile_');
    });
  });
}
