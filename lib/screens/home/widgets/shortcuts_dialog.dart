import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

/// Show the keyboard shortcuts help dialog.
void showShortcutsDialog(BuildContext context) {
  final tc = AppThemeColors.of(context);
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tc.surface,
      title: Text(l10n.raccourcisClavier, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _shortcutRow('Cmd+Q', l10n.raccourciQuitter, descColor: tc.textSecondary),
              _shortcutRow('Cmd+,', l10n.raccourciReglages, descColor: tc.textSecondary),
              _shortcutRow('Cmd+F', l10n.raccourciRechercher, descColor: tc.textSecondary),
              _shortcutRow('Cmd+Y', l10n.raccourciHistorique, descColor: tc.textSecondary),
              _shortcutRow('Cmd+G', l10n.raccourciGuideTV, descColor: tc.textSecondary),
              _shortcutRow('Cmd+?', l10n.raccourciAide, descColor: tc.textSecondary),
              const SizedBox(height: 16),
              Text(l10n.sectionLecteur, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tc.textSecondary)),
              Divider(color: tc.divider, height: 12),
              _shortcutRow('Espace', l10n.lecteurPause, descColor: tc.textSecondary),
              _shortcutRow('\u2190 / \u2192', l10n.reculerAvancer, descColor: tc.textSecondary),
              _shortcutRow('\u2191 / \u2193', '${l10n.volumePlusMoins} / Zapping (Live)', descColor: tc.textSecondary),
              _shortcutRow('F', l10n.pleinEcran, descColor: tc.textSecondary),
              _shortcutRow('M', l10n.couperSon, descColor: tc.textSecondary),
              _shortcutRow('Esc', l10n.quitterLecteur, descColor: tc.textSecondary),
              const SizedBox(height: 16),
              Text('${l10n.sectionLecteur} Live', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tc.textSecondary)),
              Divider(color: tc.divider, height: 12),
              _shortcutRow('\u2191 / \u2193', l10n.chainePrecSuiv, descColor: tc.textSecondary),
              _shortcutRow('P / N', l10n.chainePrecSuiv, descColor: tc.textSecondary),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.fermer)),
      ],
    ),
  );
}

Widget _shortcutRow(String key, String desc, {required Color descColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 80,
        child: Text(key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primaryBlue)),
      ),
      Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: descColor))),
    ]),
  );
}
