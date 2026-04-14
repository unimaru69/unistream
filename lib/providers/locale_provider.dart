import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';
import '../services/sync_service.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final code = p.getString(StorageKeys.locale) ?? 'fr';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    await p.setString(StorageKeys.locale, locale.languageCode);
    if (!mounted) return;
    state = locale;
    SyncService.instance.pushSetting('locale', locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
