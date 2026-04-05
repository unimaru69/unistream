import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/utils/theme.dart';

void main() {
  group('AppThemeColors', () {
    test('dark variant has white-based text colors', () {
      expect(AppThemeColors.dark.textPrimary, Colors.white);
      expect(AppThemeColors.dark.textSecondary, Colors.white70);
      expect(AppThemeColors.dark.textTertiary, Colors.white54);
    });

    test('light variant has dark text colors', () {
      expect(AppThemeColors.light.textPrimary.value, isNot(Colors.white.value));
      expect(AppThemeColors.light.textPrimary.alpha, 255); // fully opaque
    });

    test('dark and light surface colors differ', () {
      expect(AppThemeColors.dark.surface, isNot(AppThemeColors.light.surface));
      expect(AppThemeColors.dark.surfaceAlt, isNot(AppThemeColors.light.surfaceAlt));
    });

    test('copyWith preserves unmodified fields', () {
      final modified = AppThemeColors.dark.copyWith(textPrimary: Colors.red);
      expect(modified.textPrimary, Colors.red);
      expect(modified.surface, AppThemeColors.dark.surface);
      expect(modified.divider, AppThemeColors.dark.divider);
    });

    test('lerp at 0 returns start', () {
      final result = AppThemeColors.dark.lerp(AppThemeColors.light, 0);
      expect(result.textPrimary, AppThemeColors.dark.textPrimary);
      expect(result.surface, AppThemeColors.dark.surface);
    });

    test('lerp at 1 returns end', () {
      final result = AppThemeColors.dark.lerp(AppThemeColors.light, 1);
      expect(result.textPrimary, AppThemeColors.light.textPrimary);
      expect(result.surface, AppThemeColors.light.surface);
    });

    test('lerp at 0.5 returns midpoint', () {
      final result = AppThemeColors.dark.lerp(AppThemeColors.light, 0.5);
      // Midpoint should differ from both extremes
      expect(result.textPrimary, isNot(AppThemeColors.dark.textPrimary));
      expect(result.textPrimary, isNot(AppThemeColors.light.textPrimary));
    });

    testWidgets('of(context) returns dark variant in dark theme', (tester) async {
      late AppThemeColors tc;
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        home: Builder(builder: (context) {
          tc = AppThemeColors.of(context);
          return const SizedBox();
        }),
      ));
      expect(tc.textPrimary, AppThemeColors.dark.textPrimary);
    });

    testWidgets('of(context) returns light variant in light theme', (tester) async {
      late AppThemeColors tc;
      await tester.pumpWidget(MaterialApp(
        theme: lightTheme,
        home: Builder(builder: (context) {
          tc = AppThemeColors.of(context);
          return const SizedBox();
        }),
      ));
      expect(tc.textPrimary, AppThemeColors.light.textPrimary);
    });
  });

  group('Theme registration', () {
    test('darkTheme has AppThemeColors extension', () {
      final ext = darkTheme.extension<AppThemeColors>();
      expect(ext, isNotNull);
      expect(ext!.textPrimary, Colors.white);
    });

    test('lightTheme has AppThemeColors extension', () {
      final ext = lightTheme.extension<AppThemeColors>();
      expect(ext, isNotNull);
      expect(ext!.textPrimary, isNot(Colors.white));
    });
  });
}
