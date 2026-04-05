import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';

/// Overlay that briefly shows the current volume level.
/// Appears top-right, fades in/out, and auto-hides after 1.5 seconds.
class VolumeOsd extends StatefulWidget {
  final double volume; // 0–200

  const VolumeOsd({super.key, required this.volume});

  @override
  State<VolumeOsd> createState() => _VolumeOsdState();
}

class _VolumeOsdState extends State<VolumeOsd>
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

  /// Called by parent to trigger fade-out before removing the widget.
  void fadeOut() {
    _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.volume.clamp(0.0, 200.0);
    final norm = pct / 200.0; // 0..1

    IconData icon;
    if (pct <= 0) {
      icon = Icons.volume_off;
    } else if (pct < 50) {
      icon = Icons.volume_mute;
    } else if (pct < 120) {
      icon = Icons.volume_down;
    } else {
      icon = Icons.volume_up;
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Semantics(
        label: 'Volume ${pct.round()}%',
        child: FadeTransition(
        opacity: _anim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: norm,
                    backgroundColor: Colors.white24,
                    color: AppColors.primaryBlue,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${pct.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
