import 'package:flutter/material.dart';

class QualityBadge extends StatelessWidget {
  final String qualityBadge;
  final String bitrate;

  const QualityBadge({
    super.key,
    required this.qualityBadge,
    required this.bitrate,
  });

  @override
  Widget build(BuildContext context) {
    if (qualityBadge.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: bitrate.isNotEmpty ? bitrate : qualityBadge,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: qualityBadge == '4K' ? Colors.amber
               : qualityBadge == 'FHD' ? Colors.green
               : qualityBadge == 'HD' ? Colors.blue
               : Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(qualityBadge,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          if (bitrate.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(bitrate,
                style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ]),
      ),
    );
  }
}
