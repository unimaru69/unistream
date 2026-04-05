import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';

/// Service for parental control PIN management and blocked categories.
class ParentalService {
  ParentalService._();

  static const _storage = FlutterSecureStorage();

  // ── PIN (SHA-256 hashed, stored in secure storage) ──

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Store a new PIN (hashed).
  static Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: StorageKeys.parentalPinHash, value: hash);
  }

  /// Verify a PIN against the stored hash.
  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: StorageKeys.parentalPinHash);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  /// Remove the stored PIN.
  static Future<void> clearPin() async {
    await _storage.delete(key: StorageKeys.parentalPinHash);
  }

  /// Whether a PIN has been set.
  static Future<bool> hasPin() async {
    final stored = await _storage.read(key: StorageKeys.parentalPinHash);
    return stored != null && stored.isNotEmpty;
  }

  // ── Blocked categories (SharedPreferences, per profile) ──

  /// Get the set of blocked category IDs for a profile.
  static Future<Set<String>> getBlockedCategories(String profileId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.blockedCategories(profileId));
    if (raw == null) return {};
    final list = (jsonDecode(raw) as List).cast<String>();
    return list.toSet();
  }

  /// Set the blocked category IDs for a profile.
  static Future<void> setBlockedCategories(
      String profileId, Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        StorageKeys.blockedCategories(profileId), jsonEncode(ids.toList()));
  }
}
