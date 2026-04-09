import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/repositories/preferences_repository.dart';

class LanguagePrefsSection extends ConsumerStatefulWidget {
  const LanguagePrefsSection({super.key});

  @override
  ConsumerState<LanguagePrefsSection> createState() => _LanguagePrefsSectionState();
}

class _LanguagePrefsSectionState extends ConsumerState<LanguagePrefsSection> {
  String _prefAudioLang = 'original';
  String _prefSubLang = 'off';

  static const _langOptions = [
    ('original', 'Original'),
    ('fr', 'Fran\u00e7ais'),
    ('en', 'English'),
    ('de', 'Deutsch'),
    ('es', 'Espa\u00f1ol'),
    ('it', 'Italiano'),
  ];
  static const _subLangOptions = [
    ('off', 'D\u00e9sactiv\u00e9s'),
    ('fr', 'Fran\u00e7ais'),
    ('en', 'English'),
    ('de', 'Deutsch'),
    ('es', 'Espa\u00f1ol'),
    ('it', 'Italiano'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLangPrefs();
  }

  Future<void> _loadLangPrefs() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    final audio = await prefs.getPreferredAudioLang();
    final sub = await prefs.getPreferredSubLang();
    setState(() {
      _prefAudioLang = audio ?? 'original';
      _prefSubLang = sub ?? 'off';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(l10n.langues,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tc.textDisabled,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          ExcludeSemantics(child: Icon(Icons.audiotrack, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.langueAudioPreferee,
                  style: const TextStyle(fontSize: 14))),
          DropdownButton<String>(
            value: _prefAudioLang,
            dropdownColor: tc.surface,
            style: TextStyle(fontSize: 13, color: tc.textPrimary),
            underline: const SizedBox.shrink(),
            items: _langOptions
                .map((opt) => DropdownMenuItem(
                      value: opt.$1,
                      child: Text(opt.$2),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _prefAudioLang = v);
              ref.read(preferencesRepositoryProvider).setPreferredAudioLang(v);
            },
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          ExcludeSemantics(child: Icon(Icons.subtitles, size: 20, color: tc.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.langueSousTitresPreferee,
                  style: const TextStyle(fontSize: 14))),
          DropdownButton<String>(
            value: _prefSubLang,
            dropdownColor: tc.surface,
            style: TextStyle(fontSize: 13, color: tc.textPrimary),
            underline: const SizedBox.shrink(),
            items: _subLangOptions
                .map((opt) => DropdownMenuItem(
                      value: opt.$1,
                      child: Text(opt.$1 == 'off' ? l10n.desactive : opt.$2),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _prefSubLang = v);
              ref.read(preferencesRepositoryProvider).setPreferredSubLang(v);
            },
          ),
        ]),
      ],
    );
  }
}
