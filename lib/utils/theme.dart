import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/form_factor.dart';
import 'package:unistream/core/storage_keys.dart';
import 'package:unistream/core/theme_colors.dart';

/// From-the-couch focus ring for every Material button on Android TV.
///
/// Material's default focus indication is a ~10% overlay tint —
/// invisible at 3 metres, so screens whose only focusables are buttons
/// (onboarding welcome, dialogs…) look like "nothing is focused" on a
/// TV even when traversal works. A thick ring is the leanback
/// convention. Off TV this resolves to null → framework defaults.
///
/// The theme finals below are lazy, so [FormFactorInfo] is already
/// initialised (main() awaits it before runApp) when this evaluates.
WidgetStateProperty<BorderSide?>? _tvFocusSide() => FormFactorInfo.isAndroidTv
    ? WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? const BorderSide(color: AppColors.primaryBlueLighter, width: 3)
            : null,
      )
    : null;

FilledButtonThemeData _filledButtonTheme() =>
    FilledButtonThemeData(style: ButtonStyle(side: _tvFocusSide()));
TextButtonThemeData _textButtonTheme() =>
    TextButtonThemeData(style: ButtonStyle(side: _tvFocusSide()));
OutlinedButtonThemeData _outlinedButtonTheme() =>
    OutlinedButtonThemeData(style: ButtonStyle(side: _tvFocusSide()));
ElevatedButtonThemeData _elevatedButtonTheme() =>
    ElevatedButtonThemeData(style: ButtonStyle(side: _tvFocusSide()));
IconButtonThemeData _iconButtonTheme() =>
    IconButtonThemeData(style: ButtonStyle(side: _tvFocusSide()));

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
  dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkSurface),
  popupMenuTheme: const PopupMenuThemeData(color: AppColors.darkSurface),
  filledButtonTheme: _filledButtonTheme(),
  textButtonTheme: _textButtonTheme(),
  outlinedButtonTheme: _outlinedButtonTheme(),
  elevatedButtonTheme: _elevatedButtonTheme(),
  iconButtonTheme: _iconButtonTheme(),
  extensions: const [AppThemeColors.dark],
);

final lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.lightTextPrimary,
    elevation: 0.5,
    iconTheme: IconThemeData(color: AppColors.lightIcon),
  ),
  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryBlue,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
  ),
  cardColor: Colors.white,
  dividerColor: AppColors.lightDivider,
  dialogTheme: const DialogThemeData(backgroundColor: AppColors.lightSurface),
  popupMenuTheme: const PopupMenuThemeData(color: AppColors.lightSurface),
  filledButtonTheme: _filledButtonTheme(),
  textButtonTheme: _textButtonTheme(),
  outlinedButtonTheme: _outlinedButtonTheme(),
  elevatedButtonTheme: _elevatedButtonTheme(),
  iconButtonTheme: _iconButtonTheme(),
  extensions: const [AppThemeColors.light],
);
