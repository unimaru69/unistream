import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../services/tmdb_service.dart';

/// Horizontal scroller of cast avatars + name/role. Taps on a card do
/// nothing for now (no person-detail screen).
class TmdbCastRow extends StatelessWidget {
  const TmdbCastRow({super.key, required this.cast});
  final List<TmdbCast> cast;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = cast[i];
          final url = TmdbService.image(c.profilePath, size: 'w185');
          return SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(
                  child: url != null
                      ? CachedNetworkImage(
                          cacheManager: AppCacheManager.instance,
                          imageUrl: url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 80,
                            height: 80,
                            color: AppColors.darkSurface,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: AppColors.darkSurface,
                            child: const Icon(Icons.person, color: Colors.white30),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppColors.darkSurface,
                          child: const Icon(Icons.person, color: Colors.white30),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (c.character.isNotEmpty)
                  Text(
                    c.character,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
