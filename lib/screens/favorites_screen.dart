import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../core/typography.dart';
import '../l10n/app_localizations.dart';
import '../models/favorite_item.dart';
import '../models/vod_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/watch_progress_provider.dart';
import '../repositories/content_repository.dart';
import '../utils/content_key.dart';
import '../utils/routes.dart';
import '../widgets/plex_backdrop.dart';
import 'player/player_screen.dart';
import 'series_detail_screen.dart';
import 'vod/vod_detail_screen.dart';

/// Cross-mode favourites + watchlist screen. Mirror of the tvOS
/// `FavoritesView` (`tvos/.../Favorites/FavoritesView.swift`):
/// segmented toggle Favoris / À regarder, three sections Live /
/// Films / Séries, poster-card grids.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

enum _ListKind { favorites, watchlist }

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  _ListKind _selected = _ListKind.favorites;

  ContentRepository get _repo => ref.read(contentRepositoryProvider);

  void _openFavorite(FavoriteItem fav) {
    switch (fav.mode) {
      case 'live':
        final id = fav.streamId;
        if (id == null || id.isEmpty) return;
        final url = _repo.getLiveStreamUrl(id);
        final contentKey = ContentKey.make(ContentKey.live, id);
        ref.read(watchProgressActionsProvider).saveHistory(
              contentKey,
              fav.name,
              fav.cover,
              url,
              'live',
            );
        Navigator.push(
          context,
          slideRoute(PlayerScreen(
            url: url,
            title: fav.name,
            streamId: id,
          )),
        );
        break;
      case 'series':
        final sid = fav.seriesId ?? fav.streamId ?? fav.key;
        Navigator.push(
          context,
          slideRoute(SeriesDetailScreen(
            seriesId: sid,
            title: fav.name,
            cover: fav.cover,
            rating: fav.rating,
          )),
        );
        break;
      case 'vod':
      default:
        final vod = VodItem.fromJson(<String, dynamic>{
          'stream_id': fav.streamId ?? fav.key,
          'name': fav.name,
          'cover': fav.cover,
          'stream_icon': fav.streamIcon ?? fav.cover,
          'category_id': fav.categoryId,
          'container_extension': fav.containerExtension ?? 'mp4',
          'rating': fav.rating,
        });
        Navigator.push(
          context,
          slideRoute(VodDetailScreen(vod: vod)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favs = ref.watch(favoritesProvider).items;
    final wl = ref.watch(watchlistProvider).items;
    final source = _selected == _ListKind.favorites ? favs : wl;
    final items = List<FavoriteItem>.from(source)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final liveItems =
        items.where((f) => f.mode == 'live').toList(growable: false);
    final movieItems =
        items.where((f) => f.mode == 'vod').toList(growable: false);
    final seriesItems =
        items.where((f) => f.mode == 'series').toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          _selected == _ListKind.favorites ? l10n.favoris : l10n.aRegarder,
          style: DSText.title2.copyWith(color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const PlexBackdrop(imageUrl: '', blurSigma: 0),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DS.padding.screenHorizontal,
                    vertical: DS.space.md,
                  ),
                  child: _SegmentedToggle(
                    selected: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? _EmptyState(kind: _selected)
                      : ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: DS.padding.screenHorizontal,
                            vertical: DS.space.md,
                          ),
                          children: <Widget>[
                            if (liveItems.isNotEmpty)
                              _Section(
                                title: l10n.live,
                                count: liveItems.length,
                                items: liveItems,
                                aspectRatio: 1.0,
                                onTap: _openFavorite,
                              ),
                            if (movieItems.isNotEmpty)
                              _Section(
                                title: l10n.vod,
                                count: movieItems.length,
                                items: movieItems,
                                aspectRatio: 2 / 3,
                                onTap: _openFavorite,
                              ),
                            if (seriesItems.isNotEmpty)
                              _Section(
                                title: l10n.series,
                                count: seriesItems.length,
                                items: seriesItems,
                                aspectRatio: 2 / 3,
                                onTap: _openFavorite,
                              ),
                            SizedBox(height: DS.space.xxl),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.selected, required this.onChanged});

  final _ListKind selected;
  final ValueChanged<_ListKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ToggleButtons(
        isSelected: <bool>[
          selected == _ListKind.favorites,
          selected == _ListKind.watchlist,
        ],
        onPressed: (i) =>
            onChanged(i == 0 ? _ListKind.favorites : _ListKind.watchlist),
        borderRadius: BorderRadius.circular(DS.radius.pill),
        selectedColor: Colors.white,
        fillColor: AppColors.primaryBlue,
        color: DS.colour.textSecondary,
        constraints: const BoxConstraints(minHeight: 40, minWidth: 160),
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.favorite, size: 16),
              SizedBox(width: DS.space.xs),
              Text(l10n.favoris),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.bookmark, size: 16),
              SizedBox(width: DS.space.xs),
              Text(l10n.aRegarder),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.count,
    required this.items,
    required this.aspectRatio,
    required this.onTap,
  });

  final String title;
  final int count;
  final List<FavoriteItem> items;
  final double aspectRatio;
  final void Function(FavoriteItem) onTap;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    // ~180-px tiles target — bumps to 6-7 columns on a 1280-wide
    // window, drops to 3 on mobile portrait.
    final tileWidth = aspectRatio < 1 ? 160.0 : 200.0;
    final columns =
        ((viewportWidth - 2 * DS.padding.screenHorizontal) / (tileWidth + 16))
            .floor()
            .clamp(2, 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            top: DS.space.lg,
            bottom: DS.space.sm,
          ),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: DSText.title2.copyWith(color: Colors.white),
              ),
              SizedBox(width: DS.space.sm),
              Text(
                '$count',
                style: DSText.body.copyWith(color: DS.colour.textTertiary),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: DS.space.md,
            mainAxisSpacing: DS.space.md,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _FavoriteCard(
            fav: items[i],
            onTap: () => onTap(items[i]),
          ),
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatefulWidget {
  const _FavoriteCard({required this.fav, required this.onTap});

  final FavoriteItem fav;
  final VoidCallback onTap;

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _hovered = false;

  /// Setting hover state after a tap-triggered navigation can land on
  /// an inactive Element (`MouseRegion.onExit` fires as the cursor
  /// leaves the disappearing card). Guard against the
  /// `_elements.contains(element)` framework assertion by skipping
  /// setState when the route isn't on top.
  void _setHover(bool v) {
    if (_hovered == v || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.fav.cover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AnimatedScale(
                scale: _hovered ? DS.focus.chipScale : 1.0,
                duration: DS.focus.animation,
                curve: DS.focus.curve,
                child: AnimatedContainer(
                  duration: DS.focus.animation,
                  curve: DS.focus.curve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DS.radius.card),
                    boxShadow: _hovered
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: DS.focus.shadowOpacity,
                              ),
                              blurRadius: DS.focus.shadowRadius,
                              offset: Offset(0, DS.focus.shadowY),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(
                        alpha: _hovered ? 0.7 : 0,
                      ),
                      width: DS.focus.ringWidth,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radius.card),
                    // Live channels ship landscape logos that don't
                    // match the portrait poster aspect of the card —
                    // `BoxFit.cover` crops them aggressively (BeIN /
                    // CANAL+ logos were sliced in half). `contain`
                    // letterboxes the logo inside the dark surface
                    // background and keeps it readable. Mirror of
                    // the `search_screen` tile (which already does
                    // `mode == 'live' ? contain : cover`).
                    child: Container(
                      color: AppColors.darkSurface,
                      // Small inset around the logo so it doesn't
                      // butt against the rounded corners.
                      padding: widget.fav.mode == 'live'
                          ? const EdgeInsets.all(8)
                          : EdgeInsets.zero,
                      child: cover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              cacheManager: AppCacheManager.instance,
                              fit: widget.fav.mode == 'live'
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.darkSurface),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.darkSurface,
                                child: Icon(
                                  _iconFor(widget.fav.mode),
                                  color: DS.colour.textTertiary,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.darkSurface,
                              child: Icon(
                                _iconFor(widget.fav.mode),
                                color: DS.colour.textTertiary,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: DS.space.xs),
            Text(
              widget.fav.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSText.caption.copyWith(
                color: DS.colour.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String mode) {
    switch (mode) {
      case 'live':
        return Icons.live_tv;
      case 'series':
        return Icons.tv;
      default:
        return Icons.movie;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final _ListKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFav = kind == _ListKind.favorites;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isFav ? Icons.favorite_border : Icons.bookmark_border,
            size: 48,
            color: DS.colour.textTertiary,
          ),
          SizedBox(height: DS.space.md),
          Text(
            isFav ? l10n.favoris : l10n.aRegarder,
            style: DSText.title2.copyWith(color: DS.colour.textSecondary),
          ),
          SizedBox(height: DS.space.xs),
          Text(
            isFav
                ? 'Aucun favori pour le moment'
                : 'Aucun élément à regarder',
            style: DSText.body.copyWith(color: DS.colour.textTertiary),
          ),
        ],
      ),
    );
  }
}
