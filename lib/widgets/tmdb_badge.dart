import 'package:flutter/material.dart';

/// Tiny pill that tags content as coming from TMDB — required by their
/// attribution guidelines and useful for user trust.
class TmdbBadge extends StatelessWidget {
  const TmdbBadge({super.key, this.label = 'via TMDB'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
