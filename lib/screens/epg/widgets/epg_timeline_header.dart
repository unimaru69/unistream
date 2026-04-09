import 'package:flutter/material.dart';
import '../../../core/colors.dart';
import 'package:unistream/core/theme_colors.dart';

/// 24-hour timeline header with current-time marker for the EPG grid.
class EpgTimelineHeader extends StatelessWidget {
  const EpgTimelineHeader({
    super.key,
    required this.dayStart,
    required this.hourWidth,
  });

  final DateTime dayStart;
  final double hourWidth;

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return ExcludeSemantics(child: SizedBox(
      width: hourWidth * 24,
      height: 30,
      child: Stack(children: [
        for (var h = 0; h < 24; h++)
          Positioned(
            left: h * hourWidth,
            top: 0, bottom: 0,
            child: Container(
              width: hourWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.darkText,
                border: Border(left: BorderSide(color: tc.divider, width: 0.5)),
              ),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: TextStyle(fontSize: 10, color: tc.textTertiary),
              ),
            ),
          ),
        // Current time marker
        Positioned(
          left: DateTime.now().difference(dayStart).inMinutes * hourWidth / 60,
          top: 0, bottom: 0,
          child: Container(width: 2, color: Colors.redAccent),
        ),
      ]),
    ));
  }
}
