import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

String _decodeEpgTitle(String s) {
  if (s.isEmpty) return s;
  try { return utf8.decode(base64.decode(s)); } catch (_) { return s; }
}

/// A single catch-up program entry for the horizontal carousel.
class CatchupProgram {
  final String streamId;
  final String channelName;
  final String channelIcon;
  final String title;
  final String description;
  final DateTime startUtc;
  final DateTime endUtc;
  final int durationMin;
  /// Server-local start time string (preferred for timeshift URL).
  final String serverLocalStart;

  const CatchupProgram({
    required this.streamId,
    required this.channelName,
    required this.channelIcon,
    required this.title,
    required this.description,
    required this.startUtc,
    required this.endUtc,
    required this.durationMin,
    this.serverLocalStart = '',
  });
}

// Logo background now from AppThemeColors.logoBg

/// Horizontal carousel of recently-aired catch-up programs.
///
/// Only shown when mode is live and there are catch-up programs available.
class CatchupRow extends StatelessWidget {
  final List<CatchupProgram> programs;
  final void Function(CatchupProgram program) onTap;

  const CatchupRow({
    super.key,
    required this.programs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) return const SizedBox.shrink();
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          const Icon(Icons.replay, size: 14, color: AppColors.accentGreen),
          const SizedBox(width: 6),
          Text(l10n.programmesRecents,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: tc.textTertiary, letterSpacing: 0.8)),
        ]),
      ),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: programs.length,
          itemBuilder: (_, i) {
            final prog = programs[i];
            final ago = _timeAgo(prog.endUtc, l10n);
            return GestureDetector(
              onTap: () => onTap(prog),
              child: Container(
                width: 180,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tc.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tc.divider, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel name + replay icon
                    Row(children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: tc.logoBg,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: prog.channelIcon.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.network(prog.channelIcon,
                                    width: 20, height: 20, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        Icon(Icons.tv, size: 12, color: tc.borderColor)),
                              )
                            : Icon(Icons.tv, size: 12, color: tc.borderColor),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(prog.channelName,
                            style: TextStyle(fontSize: 10, color: tc.textDisabled,
                                fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(Icons.replay, size: 10, color: AppColors.accentGreen),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    // Program title (decode base64 from EPG)
                    Expanded(
                      child: Text(_decodeEpgTitle(prog.title),
                          style: TextStyle(fontSize: 12, color: tc.textPrimary,
                              fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    // Time ago + duration
                    Row(children: [
                      Flexible(child: Text(ago,
                          style: TextStyle(fontSize: 9, color: tc.textDisabled),
                          overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Text('${prog.durationMin} min',
                          style: TextStyle(fontSize: 9, color: tc.textDisabled)),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Divider(color: tc.divider, height: 1),
    ]);
  }

  String _timeAgo(DateTime endUtc, AppLocalizations l10n) {
    final diff = DateTime.now().toUtc().difference(endUtc);
    if (diff.inMinutes < 1) return l10n.ilYA('< 1 min');
    if (diff.inMinutes < 60) return l10n.ilYA('${diff.inMinutes} min');
    if (diff.inHours < 24) return l10n.ilYA('${diff.inHours}h');
    return l10n.ilYA('${diff.inDays}j');
  }
}
