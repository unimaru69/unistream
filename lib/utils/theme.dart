import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/storage_keys.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadThemeMode() async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString(StorageKeys.themeMode) ?? 'dark';
  switch (v) {
    case 'light':  themeNotifier.value = ThemeMode.light; break;
    case 'system': themeNotifier.value = ThemeMode.system; break;
    default:       themeNotifier.value = ThemeMode.dark;
  }
}

Future<void> saveThemeMode(ThemeMode mode) async {
  final p = await SharedPreferences.getInstance();
  final v = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
  await p.setString(StorageKeys.themeMode, v);
  themeNotifier.value = mode;
}

final darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primaryBlue,
    surface: AppColors.darkSurface,
  ),
);

final lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.darkText,
    elevation: 0.5,
  ),
  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryBlue,
    surface: Color(0xFFFFFFFF),
    onSurface: AppColors.darkText,
  ),
  cardColor: Colors.white,
  dividerColor: Colors.black12,
);
