import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../services/sync_service.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final v = p.getString(StorageKeys.themeMode) ?? 'dark';
    switch (v) {
      case 'light':
        state = ThemeMode.light;
      case 'system':
        state = ThemeMode.system;
      default:
        state = ThemeMode.dark;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final v = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await p.setString(StorageKeys.themeMode, v);
    if (!mounted) return;
    state = mode;
    SyncService.instance.pushSetting('themeMode', v);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
