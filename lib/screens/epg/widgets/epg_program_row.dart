import 'package:flutter/material.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../core/colors.dart';
import '../../../models/channel.dart';
import '../../../models/parsed_epg_program.dart';
import '../../../services/epg_reminder_service.dart';
import '../../../services/xtream_api.dart';
import '../../../utils/routes.dart';
import '../../player/player_screen.dart';
import 'epg_program_detail_dialog.dart';

/// Renders a single row of EPG programs for one channel in the grid.
class EpgProgramRow extends StatelessWidget {
  const EpgProgramRow({
    super.key,
    required this.channel,
    required this.programs,
    required this.dayStart,
    required this.hourWidth,
    required this.rowHeight,
    required this.rowIndex,
    required this.searchQuery,
  });

  final Channel channel;
  final List<ParsedEpgProgram> programs;
  final DateTime dayStart;
  final double hourWidth;
  final double rowHeight;
  final int rowIndex;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final totalWidth = hourWidth * 24;
    final hasCatchup = channel.hasCatchup;
    final sid = channel.id;

    final sorted = List<ParsedEpgProgram>.from(programs)
      ..sort((a, b) => a.start.compareTo(b.start));

    final cells = <Widget>[];
    double cursorX = 0;

    for (final prog in sorted) {
      var leftPx = prog.start.difference(dayStart).inMinutes * hourWidth / 60;
      var widthPx = prog.end.difference(prog.start).inMinutes * hourWidth / 60;

      if (leftPx < 0) { widthPx += leftPx; leftPx = 0; }
      if (leftPx + widthPx > totalWidth) widthPx = totalWidth - leftPx;
      if (widthPx <= 2) continue;
      if (leftPx < cursorX) {
        final overlap = cursorX - leftPx;
        leftPx = cursorX;
        widthPx -= overlap;
        if (widthPx <= 2) continue;
      }

      if (leftPx > cursorX) {
        cells.add(SizedBox(width: leftPx - cursorX));
      }

      final isCurrent = prog.isCurrent;
      final isPast = prog.isPast;
      final canReplay = isPast && hasCatchup;
      final isFuture = prog.isFuture;
      final hasReminder = isFuture && EpgReminderService.instance.hasReminder(sid, prog.start.toUtc());
      final title = '${canReplay ? '\u21BB ' : ''}${prog.title}';

      final matchesSearch = searchQuery.isNotEmpty &&
          prog.title.toLowerCase().contains(searchQuery);
      final cellColor = matchesSearch
          ? Colors.amber.withValues(alpha: 0.35)
          : isCurrent
          ? AppColors.primaryBlue.withValues(alpha: 0.4)
          : canReplay
          ? AppColors.accentGreen.withValues(alpha: 0.25)
          : isPast
          ? tc.divider.withValues(alpha: 0.3)
          : tc.divider.withValues(alpha: 0.5);
      final cellBorder = isCurrent
          ? Border.all(color: AppColors.primaryBlue, width: 1)
          : canReplay
          ? Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4), width: 0.5)
          : null;
      final textColor = isCurrent ? tc.textPrimary
          : canReplay ? tc.textSecondary
          : isPast ? tc.borderColor
          : tc.textSecondary;

      final cellWidth = widthPx - 1;
      final descTrunc = prog.description.length > 100 ? '${prog.description.substring(0, 100)}\u2026' : prog.description;

      cells.add(SizedBox(
        width: cellWidth > 0 ? cellWidth : 0,
        child: Semantics(
          button: true,
          label: '${prog.title}, ${prog.timeRange}${canReplay ? ', replay' : ''}${isCurrent ? ', en direct' : ''}',
          child: Tooltip(
            message: '${prog.title}\n${prog.timeRange}'
                '${descTrunc.isNotEmpty ? '\n$descTrunc' : ''}'
                '${canReplay ? '\n\u25B6 ${AppLocalizations.of(context)!.cliquerPourRevoir}' : ''}',
            child: GestureDetector(
              onTap: () {
                if (canReplay) {
                  final url = (prog.startServerLocal.isNotEmpty)
                      ? XtreamApi.getTimeshiftUrlFromLocal(sid, prog.startServerLocal, prog.durationMin)
                      : XtreamApi.getTimeshiftUrl(sid, prog.startUtc ?? prog.start.toUtc(), prog.durationMin);
                  Navigator.push(context, slideRoute(PlayerScreen(
                    url: url,
                    title: '${channel.name} \u2014 ${prog.title} (Replay)',
                    streamId: sid,
                    isCatchup: true,
                  )));
                } else {
                  final url = XtreamApi.getLiveStreamUrl(sid);
                  Navigator.push(context, slideRoute(PlayerScreen(
                    url: url,
                    title: '${channel.name}${isCurrent ? ' \u2014 ${prog.title}' : ''}',
                    streamId: sid,
                  )));
                }
              },
              onLongPress: () => showProgramDetailDialog(context,
                  prog: prog, channel: channel),
              onSecondaryTap: () => showProgramDetailDialog(context,
                  prog: prog, channel: channel),
              child: Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(3),
                  border: cellBorder,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: [
                  if (hasReminder)
                    const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(Icons.notifications_active, size: 10, color: Colors.amber),
                    ),
                  Expanded(child: ExcludeSemantics(child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ))),
                ]),
              ),
            ),
          ),
        ),
      ));

      cursorX = leftPx + widthPx;
    }

    if (cursorX < totalWidth) {
      cells.add(SizedBox(width: totalWidth - cursorX));
    }

    return Container(
      height: rowHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        color: rowIndex.isEven ? tc.surface : tc.surfaceAlt,
        border: Border(bottom: BorderSide(color: tc.inputFill, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: cells),
    );
  }
}
