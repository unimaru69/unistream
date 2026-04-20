import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tmdb_service.dart';

/// Compact "Bande-annonce" button. Opens the first trailer in the system
/// browser (simplest cross-platform path — launches YouTube app on mobile,
/// a browser tab on desktop).
class TmdbTrailerButton extends StatelessWidget {
  const TmdbTrailerButton({super.key, required this.videos});
  final List<TmdbVideo> videos;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.play_circle_outline, size: 18),
      label: const Text('Bande-annonce'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: () async {
        final uri = Uri.parse(videos.first.youtubeUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
