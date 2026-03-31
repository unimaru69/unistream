import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../services/xtream_api.dart';
import '../../../utils/routes.dart';
import '../player_screen.dart';

void showEpgGuide(BuildContext context, {
  required List<Map<String, String>> epgListings,
  required bool catchupSupported,
  required String? streamId,
}) {
  final now = DateTime.now();
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetCtx) {
      // Find current program index for auto-scroll
      int currentIdx = 0;
      for (var i = 0; i < epgListings.length; i++) {
        final endTs = int.tryParse(epgListings[i]['end_ts'] ?? '');
        if (endTs != null && now.isBefore(DateTime.fromMillisecondsSinceEpoch(endTs))) {
          currentIdx = i;
          break;
        }
      }
      final scrollCtrl = ScrollController(
        initialScrollOffset: (currentIdx * 56.0 - 100).clamp(0, double.infinity),
      );

      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(AppLocalizations.of(context)!.guideTV, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: epgListings.length,
              itemBuilder: (_, i) {
                final prog = epgListings[i];
                final startTs = int.tryParse(prog['start_ts'] ?? '');
                final endTs   = int.tryParse(prog['end_ts'] ?? '');
                final durMin  = int.tryParse(prog['dur_min'] ?? '0') ?? 0;

                // Determine past / current / future
                bool isPast = false;
                bool isCurrent = false;
                if (startTs != null && endTs != null) {
                  final s = DateTime.fromMillisecondsSinceEpoch(startTs);
                  final e = DateTime.fromMillisecondsSinceEpoch(endTs);
                  isCurrent = now.isAfter(s) && now.isBefore(e);
                  isPast = now.isAfter(e);
                }

                final progDesc = prog['description'] ?? '';
                return ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 44,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(prog['start'] ?? '',
                          style: TextStyle(fontSize: 11,
                              color: isCurrent ? AppColors.primaryBlue : isPast ? Colors.white24 : Colors.white38)),
                      if (isPast)
                        Text(AppLocalizations.of(context)!.passe, style: const TextStyle(fontSize: 8, color: Colors.white24))
                      else if (isCurrent)
                        Text(AppLocalizations.of(context)!.enCoursProg, style: const TextStyle(fontSize: 8, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  title: Text(prog['title'] ?? '',
                      style: TextStyle(fontSize: 13,
                          color: isCurrent ? Colors.white : isPast ? Colors.white38 : Colors.white70,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prog['end']?.isNotEmpty == true)
                        Text('\u2192 ${prog['end']}', style: TextStyle(fontSize: 10,
                            color: isPast ? Colors.white12 : Colors.white24)),
                      if (progDesc.isNotEmpty)
                        Text(progDesc, style: TextStyle(fontSize: 10,
                            color: isPast ? Colors.white24 : Colors.white38),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: (catchupSupported && isPast && startTs != null && streamId != null)
                      ? TextButton.icon(
                          icon: const Icon(Icons.replay, size: 16),
                          label: Text(AppLocalizations.of(context)!.revoir, style: const TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.accentGreen),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            // Prefer server-local string (DST-safe), fallback to UTC conversion
                            final serverLocal = prog['start_server_local'] ?? '';
                            String url;
                            if (serverLocal.isNotEmpty) {
                              url = XtreamApi.getTimeshiftUrlFromLocal(streamId, serverLocal, durMin);
                            } else {
                              final rawEpoch = int.tryParse(prog['start_epoch'] ?? '');
                              final startUtc = rawEpoch != null
                                  ? DateTime.fromMillisecondsSinceEpoch(rawEpoch * 1000, isUtc: true)
                                  : DateTime.fromMillisecondsSinceEpoch(startTs, isUtc: true);
                              url = XtreamApi.getTimeshiftUrl(streamId, startUtc, durMin);
                            }
                            Navigator.pushReplacement(context, slideRoute(PlayerScreen(
                              url: url,
                              title: '${prog['title']} (${AppLocalizations.of(context)!.replay})',
                              streamId: streamId,
                              isCatchup: true,
                            )));
                          },
                        )
                      : null,
                  tileColor: isCurrent ? AppColors.primaryBlue.withValues(alpha: 0.1) : null,
                );
              },
            ),
          ),
        ]),
      );
    },
  );
}
