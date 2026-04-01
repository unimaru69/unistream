import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/providers/locale_provider.dart';
import 'package:unistream/core/storage_keys.dart';

void main() {
  group('LocaleNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is Locale fr', () {
      final notifier = LocaleNotifier();
      expect(notifier.state, const Locale('fr'));
    });

    test('loads stored locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.locale: 'en'});
      final notifier = LocaleNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, const Locale('en'));
    });

    test('defaults to fr when no stored value', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, const Locale('fr'));
    });

    test('setLocale updates state', () async {
      final notifier = LocaleNotifier();
      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, const Locale('en'));
    });

    test('setLocale persists to SharedPreferences', () async {
      final notifier = LocaleNotifier();
      await notifier.setLocale(const Locale('en'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.locale), 'en');
    });

    test('setLocale can switch between locales', () async {
      final notifier = LocaleNotifier();
      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, const Locale('en'));

      await notifier.setLocale(const Locale('fr'));
      expect(notifier.state, const Locale('fr'));
    });
  });
}
