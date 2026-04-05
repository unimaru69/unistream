import 'package:flutter/material.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

void showSleepTimerPicker(BuildContext context, {
  required Duration? sleepRemaining,
  required void Function() onCancel,
  required void Function(Duration duration) onStart,
}) {
  final tc = AppThemeColors.of(context);
  final presets = [15, 30, 45, 60, 90, 120];
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context)!.minuterieVeille, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (sleepRemaining != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
              title: Text(AppLocalizations.of(context)!.annulerMinuterie(sleepRemaining.inMinutes),
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                onCancel();
              },
            ),
          for (final m in presets)
            ListTile(
              dense: true,
              leading: Icon(Icons.timer, color: tc.textDisabled, size: 20),
              title: Text(AppLocalizations.of(context)!.xMinutes(m)),
              onTap: () {
                Navigator.pop(ctx);
                onStart(Duration(minutes: m));
              },
            ),
        ],
      ),
    ),
  );
}
