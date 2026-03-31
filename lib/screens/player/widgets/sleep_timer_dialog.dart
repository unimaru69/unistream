import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/strings.dart';

void showSleepTimerPicker(BuildContext context, {
  required Duration? sleepRemaining,
  required void Function() onCancel,
  required void Function(Duration duration) onStart,
}) {
  final presets = [15, 30, 45, 60, 90, 120];
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkText,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(AppStrings.minuterieVeille, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (sleepRemaining != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
              title: Text('Annuler (${sleepRemaining.inMinutes} min restantes)',
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                onCancel();
              },
            ),
          for (final m in presets)
            ListTile(
              dense: true,
              leading: const Icon(Icons.timer, color: Colors.white38, size: 20),
              title: Text('$m minutes'),
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
