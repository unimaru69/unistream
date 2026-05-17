import 'package:flutter/material.dart';

import '../../../core/colors.dart';

/// Center-screen flash overlay used by the live player when the user
/// timeshifts (← / →) inside the broadcast. Mirror of the
/// `flashCenterMessage` overlay on `VLCLivePlayerViewController` —
/// shows the current offset or a "vous êtes en direct" message,
/// fades in/out, never blocks pointer events.
class TimeshiftOsd extends StatefulWidget {
  const TimeshiftOsd({
    super.key,
    required this.message,
    required this.isLive,
  });

  /// e.g. "↩ -5 min" / "● EN DIRECT" / "Limite du replay atteinte"
  final String message;

  /// True when the offset is back to 0 — toggles the colour to
  /// neutral white instead of warm-orange (which signals "in the
  /// past").
  final bool isLive;

  @override
  State<TimeshiftOsd> createState() => _TimeshiftOsdState();
}

class _TimeshiftOsdState extends State<TimeshiftOsd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void fadeOut() => _anim.reverse();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _anim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.message,
              style: TextStyle(
                color: widget.isLive
                    ? Colors.white
                    : AppColors.accentWarm,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
