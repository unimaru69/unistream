import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/services/xtream_api.dart';
import 'profile.dart';

class AppConfig {
  static String serverUrl = '';
  static String username  = '';
  static String password  = '';
  static String activeProfileId = '';

  static List<Profile> profiles = [];

  static const _secureStorage = FlutterSecureStorage();

  static bool get isConfigured =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// Prefix for profile-scoped keys
  static String get pfx => 'p_${activeProfileId}_';

  /// Read password from secure storage, with migration from SharedPreferences.
  /// Falls back to SharedPreferences if Keychain access fails.
  static Future<String> _readPassword(String profileId, SharedPreferences p) async {
    try {
      // Try secure storage first
      final securePass = await _secureStorage.read(key: 'pwd_$profileId');
      if (securePass != null && securePass.isNotEmpty) return securePass;
    } catch (e, st) {
      AppLogger.warning(LogModule.config, 'Keychain read failed for profile $profileId', error: e, stackTrace: st);
    }

    // Fallback: read from profiles_list JSON in SharedPreferences
    final raw = p.getString(StorageKeys.profilesList);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        if (e['id'] == profileId && e['password'] != null && (e['password'] as String).isNotEmpty) {
          final oldPass = e['password'] as String;
          // Try to migrate to secure storage
          try { await _secureStorage.write(key: 'pwd_$profileId', value: oldPass); } catch (e, st) { AppLogger.warning(LogModule.config, 'Failed to migrate password to secure storage', error: e, stackTrace: st); }
          return oldPass;
        }
      }
    }
    return '';
  }

  /// Save password to secure storage (best effort)
  static Future<void> _writePassword(String profileId, String password) async {
    try { await _secureStorage.write(key: 'pwd_$profileId', value: password); } catch (e, st) { AppLogger.warning(LogModule.config, 'Failed to write password to secure storage', error: e, stackTrace: st); }
  }

  /// Delete password from secure storage (best effort)
  static Future<void> _deletePassword(String profileId) async {
    try { await _secureStorage.delete(key: 'pwd_$profileId'); } catch (e, st) { AppLogger.warning(LogModule.config, 'Failed to delete password from secure storage', error: e, stackTrace: st); }
  }

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.profilesList);
    if (raw != null) {
      profiles = (jsonDecode(raw) as List)
          .map((e) => Profile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    activeProfileId = p.getString(StorageKeys.activeProfile) ?? '';

    // Load passwords from secure storage for all profiles
    for (final pr in profiles) {
      pr.password = await _readPassword(pr.id, p);
    }

    final active = profiles.where((pr) => pr.id == activeProfileId).firstOrNull;
    if (active != null) {
      serverUrl = active.serverUrl;
      username  = active.username;
      password  = active.password;
    } else if (profiles.isNotEmpty) {
      _activate(profiles.first);
      await p.setString(StorageKeys.activeProfile, activeProfileId);
    } else {
      // Legacy migration: check old keys
      final oldServer = p.getString(StorageKeys.cfgServer) ?? '';
      final oldUser   = p.getString(StorageKeys.cfgUser)   ?? '';
      final oldPass   = p.getString(StorageKeys.cfgPass)   ?? '';
      if (oldServer.isNotEmpty) {
        final pr = Profile(id: 'default', name: 'Serveur principal',
            serverUrl: oldServer, username: oldUser, password: oldPass);
        profiles = [pr];
        _activate(pr);
        await _writePassword(pr.id, oldPass);
        await _saveProfiles();
        await p.setString(StorageKeys.activeProfile, pr.id);
        // Remove old plaintext password
        await p.remove(StorageKeys.cfgPass);
      }
    }
  }

  static void _activate(Profile pr) {
    activeProfileId = pr.id;
    serverUrl = pr.serverUrl;
    username  = pr.username;
    password  = pr.password;
  }

  static Future<void> switchProfile(String profileId) async {
    final pr = profiles.firstWhere((p) => p.id == profileId);
    _activate(pr);
    // Clear API caches so the new server's data is fetched fresh
    XtreamApi.clearEpgCache();
    XtreamApi.clearStreamCache();
    final p = await SharedPreferences.getInstance();
    await p.setString(StorageKeys.activeProfile, profileId);
  }

  static Future<void> addProfile(Profile pr) async {
    profiles.add(pr);
    await _writePassword(pr.id, pr.password);
    await _saveProfiles();
  }

  static Future<void> updateProfile(Profile pr) async {
    final idx = profiles.indexWhere((p) => p.id == pr.id);
    if (idx >= 0) profiles[idx] = pr;
    if (pr.id == activeProfileId) _activate(pr);
    await _writePassword(pr.id, pr.password);
    await _saveProfiles();
  }

  static Future<void> deleteProfile(String id) async {
    profiles.removeWhere((p) => p.id == id);
    await _deletePassword(id);
    await _saveProfiles();
  }

  static Future<void> _saveProfiles() async {
    final p = await SharedPreferences.getInstance();
    // Check if secure storage works; if so, strip passwords from SharedPreferences
    bool secureAvailable = false;
    try {
      await _secureStorage.write(key: '_test', value: 'ok');
      await _secureStorage.delete(key: '_test');
      secureAvailable = true;
    } catch (e, st) { AppLogger.warning(LogModule.config, 'Secure storage availability check failed', error: e, stackTrace: st); }

    final serialized = profiles.map((e) {
      final j = e.toJson();
      if (secureAvailable) j['password'] = ''; // passwords safe in Keychain
      return j;
    }).toList();
    await p.setString(StorageKeys.profilesList, jsonEncode(serialized));
  }

  // Legacy compat — used by SettingsScreen
  static Future<void> save(String server, String user, String pass) async {
    if (activeProfileId.isEmpty) {
      final pr = Profile(id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Serveur', serverUrl: server.trim(), username: user.trim(), password: pass.trim());
      profiles.add(pr);
      _activate(pr);
      await _writePassword(pr.id, pass.trim());
      final p = await SharedPreferences.getInstance();
      await p.setString(StorageKeys.activeProfile, pr.id);
    } else {
      final pr = profiles.firstWhere((p) => p.id == activeProfileId);
      pr.serverUrl = server.trim();
      pr.username  = user.trim();
      pr.password  = pass.trim();
      _activate(pr);
      await _writePassword(pr.id, pass.trim());
    }
    await _saveProfiles();
  }
}
