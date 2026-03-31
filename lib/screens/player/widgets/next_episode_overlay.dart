import 'package:flutter/material.dart';

class NextEpisodeOverlay extends StatelessWidget {
  final Map<String, dynamic> nextEpisode;
  final int countdownSec;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  const NextEpisodeOverlay({
    super.key,
    required this.nextEpisode,
    required this.countdownSec,
    required this.onPlayNow,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4A90D9), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('\u00c9pisode suivant', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(nextEpisode['title'] ?? '\u00c9pisode suivant',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                onPressed: onPlayNow,
                child: Text('Lire maintenant ($countdownSec)'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                child: const Text('Annuler'),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}
