import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/providers/theme_provider.dart';
import 'package:unistream/core/storage_keys.dart';

void main() {
  group('ThemeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is ThemeMode.dark', () {
      final notifier = ThemeNotifier();
      expect(notifier.state, ThemeMode.dark);
    });

    test('loads light theme from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.themeMode: 'light'});
      final notifier = ThemeNotifier();
      // Wait for async _load() to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, ThemeMode.light);
    });

    test('loads system theme from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.themeMode: 'system'});
      final notifier = ThemeNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, ThemeMode.system);
    });

    test('loads dark theme from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.themeMode: 'dark'});
      final notifier = ThemeNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, ThemeMode.dark);
    });

    test('defaults to dark for unknown stored value', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.themeMode: 'unknown'});
      final notifier = ThemeNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, ThemeMode.dark);
    });

    test('setTheme to light updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      await notifier.setTheme(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.themeMode), 'light');
    });

    test('setTheme to dark updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      await notifier.setTheme(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.themeMode), 'dark');
    });

    test('setTheme to system updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      await notifier.setTheme(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.themeMode), 'system');
    });

    test('setTheme transitions between all modes', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();

      await notifier.setTheme(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      await notifier.setTheme(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);

      await notifier.setTheme(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);
    });
  });
}
