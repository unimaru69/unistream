import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadThemeMode() async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString('theme_mode') ?? 'dark';
  switch (v) {
    case 'light':  themeNotifier.value = ThemeMode.light; break;
    case 'system': themeNotifier.value = ThemeMode.system; break;
    default:       themeNotifier.value = ThemeMode.dark;
  }
}

Future<void> saveThemeMode(ThemeMode mode) async {
  final p = await SharedPreferences.getInstance();
  final v = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
  await p.setString('theme_mode', v);
  themeNotifier.value = mode;
}

final darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0A0A1A),
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF4A90D9),
    surface: const Color(0xFF12122A),
  ),
);

final lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF1A1A2E),
    elevation: 0.5,
  ),
  colorScheme: ColorScheme.light(
    primary: const Color(0xFF4A90D9),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF1A1A2E),
  ),
  cardColor: Colors.white,
  dividerColor: Colors.black12,
);
