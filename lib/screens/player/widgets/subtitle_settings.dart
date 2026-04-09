import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

void showSubtitleStylePicker(BuildContext context, {
  required double fontSize,
  required Color color,
  required double bgOpacity,
  required void Function(double fontSize) onFontSizeChanged,
  required void Function(Color color) onColorChanged,
  required void Function(double opacity) onBgOpacityChanged,
  required VoidCallback onDismissed,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colorOptions = <(Color, String)>[
    (Colors.white, l10n.blanc),
    (Colors.yellow, l10n.jaune),
    (Colors.green, l10n.vert),
    (Colors.cyan, l10n.cyan),
  ];

  // Local mutable copies for StatefulBuilder
  double localFontSize = fontSize;
  Color localColor = color;
  double localBgOpacity = bgOpacity;

  final tc = AppThemeColors.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(AppLocalizations.of(context)!.styleSousTitres,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(l10n.taille, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
              Expanded(
                child: Slider(
                  value: localFontSize,
                  min: 12, max: 48, divisions: 18,
                  label: localFontSize.round().toString(),
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) {
                    setLocal(() => localFontSize = v);
                    onFontSizeChanged(v);
                  },
                ),
              ),
              Text('${localFontSize.round()}',
                  style: TextStyle(fontSize: 13, color: tc.textSecondary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text(l10n.couleurLabel, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
              const SizedBox(width: 16),
              ...colorOptions.map((opt) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: true,
                  label: opt.$2,
                  selected: localColor.toARGB32() == opt.$1.toARGB32(),
                  child: GestureDetector(
                    onTap: () {
                      setLocal(() => localColor = opt.$1);
                      onColorChanged(opt.$1);
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: opt.$1, shape: BoxShape.circle,
                        border: Border.all(
                          color: localColor.toARGB32() == opt.$1.toARGB32()
                              ? AppColors.primaryBlue : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(l10n.fondLabel, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
              Expanded(
                child: Slider(
                  value: localBgOpacity,
                  min: 0, max: 1, divisions: 10,
                  label: '${(localBgOpacity * 100).round()}%',
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) {
                    setLocal(() => localBgOpacity = v);
                    onBgOpacityChanged(v);
                  },
                ),
              ),
              Text('${(localBgOpacity * 100).round()}%',
                  style: TextStyle(fontSize: 13, color: tc.textSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    ),
  ).then((_) => onDismissed());
}
