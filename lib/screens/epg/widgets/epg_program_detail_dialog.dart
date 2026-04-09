import 'package:flutter/material.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../models/channel.dart';
import '../../../models/parsed_epg_program.dart';
import '../../../services/epg_reminder_service.dart';

/// Shows a dialog with program details (title, time, description)
/// and optional reminder toggle for future programs.
void showProgramDetailDialog(
  BuildContext context, {
  required ParsedEpgProgram prog,
  Channel? channel,
}) {
  final tc = AppThemeColors.of(context);
  final l10n = AppLocalizations.of(context)!;
  final isFuture = prog.isFuture;
  final reminderSvc = EpgReminderService.instance;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final nowHasReminder = channel != null && isFuture
            && reminderSvc.hasReminder(channel.id, prog.start.toUtc());
        return AlertDialog(
          backgroundColor: tc.surface,
          title: Semantics(
            header: true,
            child: Text(prog.title,
                style: TextStyle(color: tc.textPrimary, fontSize: 15)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prog.timeRange,
                  style: TextStyle(color: tc.textSecondary, fontSize: 13),
                ),
                if (channel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(channel.name,
                        style: TextStyle(color: tc.textDisabled, fontSize: 12)),
                  ),
                if (prog.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(prog.description,
                      style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            if (channel != null && isFuture)
              nowHasReminder
                  ? TextButton.icon(
                      icon: const Icon(Icons.notifications_active,
                          size: 16, color: Colors.amber),
                      label: Text(l10n.rappelActif,
                          style: const TextStyle(color: Colors.amber, fontSize: 12)),
                      onPressed: () {
                        final id = '${channel.id}_${prog.start.toUtc().millisecondsSinceEpoch}';
                        reminderSvc.remove(id);
                        setDialogState(() {});
                      },
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.notifications_none, size: 16),
                      label: Text(l10n.meRappeler,
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        reminderSvc.add(EpgReminder(
                          streamId: channel.id,
                          channelName: channel.name,
                          programTitle: prog.title,
                          startUtc: prog.start.toUtc(),
                          durationMin: prog.durationMin,
                        ));
                        setDialogState(() {});
                      },
                    ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.fermer),
            ),
          ],
        );
      },
    ),
  );
}
