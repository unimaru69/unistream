import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../screens/cast_filmography_screen.dart';
import '../services/tmdb_service.dart';
import '../utils/routes.dart';

/// Horizontal scroller of cast avatars + name/role. Tapping a card
/// pushes the `CastFilmographyScreen` with the actor's TMDB id, name
/// and (when available) profile path so the destination screen can
/// show the portrait immediately while the rest of the details
/// resolve.
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
        itemBuilder: (_, i) => _CastTile(c: cast[i]),
      ),
    );
  }
}

class _CastTile extends StatefulWidget {
  const _CastTile({required this.c});
  final TmdbCast c;

  @override
  State<_CastTile> createState() => _CastTileState();
}

class _CastTileState extends State<_CastTile> {
  bool _hovered = false;

  void _setHover(bool v) {
    if (_hovered == v || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final url = TmdbService.image(c.profilePath, size: 'w185');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            slideRoute(CastFilmographyScreen(
              personId: c.id,
              initialName: c.name,
              initialProfilePath: c.profilePath,
            )),
          );
        },
        child: AnimatedScale(
          scale: _hovered ? DS.focus.chipScale : 1.0,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
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
                            child: const Icon(Icons.person,
                                color: Colors.white30),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppColors.darkSurface,
                          child: const Icon(Icons.person,
                              color: Colors.white30),
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
          ),
        ),
      ),
    );
  }
}
