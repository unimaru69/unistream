import 'package:flutter/material.dart';

/// Small OSD overlay showing buffered channel digits (top-left).
/// Displayed while the user is typing a channel number via digit keys.
class ChannelNumberOsd extends StatelessWidget {
  final String digits;

  const ChannelNumberOsd({super.key, required this.digits});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          digits,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
