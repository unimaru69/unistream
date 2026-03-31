import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

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
          border: Border.all(color: AppColors.primaryBlue, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(AppLocalizations.of(context)!.episodeSuivant, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(nextEpisode['title'] ?? AppLocalizations.of(context)!.episodeSuivant,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                onPressed: onPlayNow,
                child: Text(AppLocalizations.of(context)!.lireMaintenant(countdownSec)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                child: Text(AppLocalizations.of(context)!.annuler),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}
