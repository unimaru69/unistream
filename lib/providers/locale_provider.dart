import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage_keys.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(StorageKeys.locale) ?? 'fr';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(StorageKeys.locale, locale.languageCode);
    state = locale;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
