import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';

/// Subtitle display settings.
class SubtitleSettings {
  final double fontSize;
  final Color color;
  final double bgOpacity;
  const SubtitleSettings({
    this.fontSize = 24,
    this.color = const Color(0xFFFFFFFF),
    this.bgOpacity = 0.5,
  });
}

/// Centralizes UI preference persistence via SharedPreferences.
///
/// Screens and providers should use this instead of calling
/// [SharedPreferences.getInstance()] directly for UI settings.
class PreferencesRepository {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Grid view ──

  Future<bool?> getGridView(String profileId, String modeKey) async {
    final p = await _p;
    return p.getBool(StorageKeys.gridView(profileId, modeKey));
  }

  Future<void> setGridView(String profileId, String modeKey, bool value) async {
    final p = await _p;
    await p.setBool(StorageKeys.gridView(profileId, modeKey), value);
  }

  // ── Sort mode ──

  Future<String?> getSortMode(String profileId, String modeKey) async {
    final p = await _p;
    return p.getString(StorageKeys.sortMode(profileId, modeKey));
  }

  Future<void> setSortMode(String profileId, String modeKey, String value) async {
    final p = await _p;
    await p.setString(StorageKeys.sortMode(profileId, modeKey), value);
  }

  // ── Sidebar width ──

  Future<double?> getSidebarWidth() async {
    final p = await _p;
    return p.getDouble(StorageKeys.sidebarWidth);
  }

  Future<void> setSidebarWidth(double value) async {
    final p = await _p;
    await p.setDouble(StorageKeys.sidebarWidth, value);
  }

  // ── Subtitle settings ──

  Future<SubtitleSettings> getSubtitleSettings(String profileId) async {
    final p = await _p;
    final fs = p.getDouble(StorageKeys.subtitleFontSize(profileId));
    final colorVal = p.getInt(StorageKeys.subtitleColor(profileId));
    final bgOp = p.getDouble(StorageKeys.subtitleBgOpacity(profileId));
    return SubtitleSettings(
      fontSize: fs ?? 24,
      color: colorVal != null ? Color(colorVal) : const Color(0xFFFFFFFF),
      bgOpacity: bgOp ?? 0.5,
    );
  }

  Future<void> setSubtitleSettings(String profileId, SubtitleSettings s) async {
    final p = await _p;
    await p.setDouble(StorageKeys.subtitleFontSize(profileId), s.fontSize);
    await p.setInt(StorageKeys.subtitleColor(profileId), s.color.toARGB32());
    await p.setDouble(StorageKeys.subtitleBgOpacity(profileId), s.bgOpacity);
  }

  // ── Language preferences ──

  Future<String?> getPreferredAudioLang() async {
    final p = await _p;
    return p.getString(StorageKeys.prefAudioLang);
  }

  Future<String?> getPreferredSubLang() async {
    final p = await _p;
    return p.getString(StorageKeys.prefSubLang);
  }

  // ── Language preferences ──

  Future<void> setPreferredAudioLang(String lang) async {
    final p = await _p;
    await p.setString(StorageKeys.prefAudioLang, lang);
  }

  Future<void> setPreferredSubLang(String lang) async {
    final p = await _p;
    await p.setString(StorageKeys.prefSubLang, lang);
  }

  // ── Advanced / retry settings ──

  Future<int> getRetryMaxAttempts() async {
    final p = await _p;
    return p.getInt(StorageKeys.retryMaxAttempts) ?? 3;
  }

  Future<void> setRetryMaxAttempts(int value) async {
    final p = await _p;
    await p.setInt(StorageKeys.retryMaxAttempts, value);
  }

  Future<int> getRetryTimeoutSec() async {
    final p = await _p;
    return p.getInt(StorageKeys.retryTimeoutSec) ?? 15;
  }

  Future<void> setRetryTimeoutSec(int value) async {
    final p = await _p;
    await p.setInt(StorageKeys.retryTimeoutSec, value);
  }

  // ── EPG cache on disk ──

  Future<int> countPersistedEpgEntries(String profileId) async {
    final p = await _p;
    final raw = p.getString(StorageKeys.epgCache(profileId));
    if (raw == null || raw.isEmpty) return 0;
    return RegExp(r'"[^"]+"\s*:\s*\{').allMatches(raw).length;
  }

  // ── Search history ──

  Future<List<String>> getSearchHistory() async {
    final p = await _p;
    return p.getStringList('search_history') ?? [];
  }

  Future<void> setSearchHistory(List<String> history) async {
    final p = await _p;
    await p.setStringList('search_history', history);
  }

  Future<void> clearSearchHistory() async {
    final p = await _p;
    await p.remove('search_history');
  }
}

/// Riverpod provider for [PreferencesRepository].
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository();
});
