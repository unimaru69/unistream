import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_colors.dart';
import '../../../utils/theme.dart';
import '../../../providers/locale_provider.dart';
import 'package:unistream/l10n/app_localizations.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(l10n.apparence,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tc.textDisabled,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, mode, _) => Row(children: [
            ExcludeSemantics(child: Icon(Icons.brightness_6, size: 20, color: tc.textTertiary)),
            const SizedBox(width: 12),
            Text(l10n.themeMode, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeSysteme,
                        style: const TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeSombre,
                        style: const TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeClair,
                        style: const TextStyle(fontSize: 12))),
              ],
              selected: {mode},
              onSelectionChanged: (v) => saveThemeMode(v.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          ExcludeSemantics(child: Icon(Icons.language, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Text(l10n.langueInterface,
              style: const TextStyle(fontSize: 14)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'fr',
                  label:
                      Text('Fran\u00e7ais', style: TextStyle(fontSize: 12))),
              ButtonSegment(
                  value: 'en',
                  label: Text('English', style: TextStyle(fontSize: 12))),
            ],
            selected: {currentLocale.languageCode},
            onSelectionChanged: (v) =>
                ref.read(localeProvider.notifier).setLocale(Locale(v.first)),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ]),
      ],
    );
  }
}
