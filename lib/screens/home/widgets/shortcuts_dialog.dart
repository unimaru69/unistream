import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

/// Show the keyboard shortcuts help dialog.
void showShortcutsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      title: Text(l10n.raccourcisClavier, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _shortcutRow('Cmd+Q', l10n.raccourciQuitter),
              _shortcutRow('Cmd+,', l10n.raccourciReglages),
              _shortcutRow('Cmd+F', l10n.raccourciRechercher),
              _shortcutRow('Cmd+Y', l10n.raccourciHistorique),
              _shortcutRow('Cmd+G', l10n.raccourciGuideTV),
              _shortcutRow('Cmd+?', l10n.raccourciAide),
              const SizedBox(height: 16),
              Text(l10n.sectionLecteur, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
              const Divider(color: Colors.white12, height: 12),
              _shortcutRow('Espace', l10n.lecteurPause),
              _shortcutRow('\u2190 / \u2192', l10n.reculerAvancer),
              _shortcutRow('\u2191 / \u2193', '${l10n.volumePlusMoins} / Zapping (Live)'),
              _shortcutRow('F', l10n.pleinEcran),
              _shortcutRow('M', l10n.couperSon),
              _shortcutRow('Esc', l10n.quitterLecteur),
              const SizedBox(height: 16),
              Text('${l10n.sectionLecteur} Live', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
              const Divider(color: Colors.white12, height: 12),
              _shortcutRow('\u2191 / \u2193', l10n.chainePrecSuiv),
              _shortcutRow('P / N', l10n.chainePrecSuiv),
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

Widget _shortcutRow(String key, String desc) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 80,
        child: Text(key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primaryBlue)),
      ),
      Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70))),
    ]),
  );
}
