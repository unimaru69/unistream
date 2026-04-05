import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';

/// Service for parental control PIN management and blocked categories.
///
/// The PIN is stored as a SHA-256 hash in SharedPreferences. Since the hash
/// is not reversible this is safe and avoids requiring Keychain entitlements
/// on macOS.
class ParentalService {
  ParentalService._();

  // ── PIN (SHA-256 hashed, stored in SharedPreferences) ──

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Store a new PIN (hashed).
  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await p.setString(StorageKeys.parentalPinHash, hash);
  }

  /// Verify a PIN against the stored hash.
  static Future<bool> verifyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(StorageKeys.parentalPinHash);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  /// Remove the stored PIN.
  static Future<void> clearPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.parentalPinHash);
  }

  /// Whether a PIN has been set.
  static Future<bool> hasPin() async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(StorageKeys.parentalPinHash);
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
