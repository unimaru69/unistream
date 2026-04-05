import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

/// Day navigation bar for the EPG grid (Hier / Aujourd'hui / Demain).
class EpgDayNavigator extends StatelessWidget {
  final DateTime dayStart;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String Function(DateTime) formatDay;
  final VoidCallback? onTapDate;

  const EpgDayNavigator({
    super.key,
    required this.dayStart,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.formatDay,
    this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      color: AppColors.darkText,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        TextButton.icon(
          onPressed: canGoPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: Text(l10n.hier, style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: canGoPrev ? tc.textSecondary : tc.borderColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTapDate,
          child: Text(
            formatDay(dayStart),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.textPrimary),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: Text(l10n.demain, style: const TextStyle(fontSize: 12)),
          label: const Icon(Icons.chevron_right, size: 18),
          style: TextButton.styleFrom(
            foregroundColor: canGoNext ? tc.textSecondary : tc.borderColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ]),
    );
  }
}
