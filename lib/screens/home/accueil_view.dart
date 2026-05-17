import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache_config.dart';
import '../../core/colors.dart';
import '../../core/design_tokens.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/content_mode.dart';
import '../../models/continue_watching_item.dart';
import '../../models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/watch_progress_provider.dart';
import 'widgets/ambient_wallpaper.dart';
import 'widgets/catchup_row.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/home_hero.dart';

/// Apple-TV+-style Accueil. Aggregates hero rotation, Continue Watching,
/// favourite shelves (live channels / films / séries), Recently Added,
/// Catch-up — all the cross-mode surfaces that didn't fit naturally in
/// the Live / Films / Séries split views.
///
/// Mirror of the tvOS `HomeContentView`
/// (`tvos/UniStreamTV/UniStreamTV/Views/Home/HomeTabView.swift`),
/// adapted for desktop / tablet:
/// - hover-driven highlight on desktop, no hover on iPad — favourite
///   tiles open on tap
/// - full-screen ambient wallpaper backed by the hero's current rotation
///   item; transitions cross-fade as the carousel auto-advances
///
/// The wallpaper sits behind the entire scrollable content (under the
/// translucent app bar). Pulling its TMDB backdrop via the
/// [tmdbLookupProvider] keeps the wallpaper sharp at full-window size —
/// the IPTV-provided posters would look pixelated stretched out.
class AccueilView extends ConsumerStatefulWidget {
  const AccueilView({
    super.key,
    required this.featured,
    required this.catchupPrograms,
    required this.topInset,
    required this.onPlayItem,
    required this.onPlayFavorite,
    required this.onPlayCatchup,
    required this.onPlayContinueItem,
  });

  /// Mixed list of [VodItem] / [SeriesItem] used to feed the hero
  /// rotation and the Recently Added row. The host loads this once at
  /// init.
  final List<dynamic> featured;

  /// Past catch-up programs (last 24 h on catch-up-enabled channels).
  final List<CatchupProgram> catchupPrograms;

  /// Padding reserved for the translucent app bar above so the hero
  /// can bleed under it without colliding with the toolbar.
  final double topInset;

  final void Function(dynamic item) onPlayItem;
  final void Function(FavoriteItem fav) onPlayFavorite;
  final void Function(CatchupProgram program) onPlayCatchup;

  /// Continue Watching items carry their own URL + resume key — so we
  /// open the player straight away instead of detouring through detail
  /// screens (which would only know the *episode* of a series, not the
  /// series itself).
  final void Function(ContinueWatchingItem item) onPlayContinueItem;

  @override
  ConsumerState<AccueilView> createState() => _AccueilViewState();
}

class _AccueilViewState extends ConsumerState<AccueilView> {
  /// Current ambient-wallpaper target driven by the hero's auto-rotation.
  dynamic _wallpaperItem;

  /// Wallpaper override while the user is hovering a shelf card. When
  /// non-null, this wins over `_wallpaperItem` so the backdrop
  /// "follows the eye" across the page — Apple-TV+-style focus-driven
  /// preview. Cleared on mouse exit.
  dynamic _hoveredItem;

  @override
  Widget build(BuildContext context) {
    // Resolution order: hovered card → hero rotation → first featured.
    final wallpaperItem = _hoveredItem ??
        _wallpaperItem ??
        (widget.featured.isNotEmpty ? widget.featured.first : null);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AmbientWallpaper(item: wallpaperItem),
        _content(context),
      ],
    );
  }

  void _onItemHover(dynamic source, bool isHovered) {
    Future<void>.microtask(() {
      if (!mounted) return;
      // Skip setState while we're behind another route (the
      // microtask was queued from a MouseRegion event, but by the
      // time it fires the user may have already tapped a card and
      // pushed a detail screen — `mounted` is still true on the
      // deactivated AccueilView but its element is no longer in
      // BuildOwner's `_elements`, so a setState would trip the
      // framework assertion).
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (isHovered) {
        final target = toWallpaperTarget(source);
        if (target == null) return;
        if (identical(_hoveredItem, target)) return;
        setState(() => _hoveredItem = target);
      } else {
        if (_hoveredItem == null) return;
        setState(() => _hoveredItem = null);
      }
    });
  }

  /// Wraps any tap callback so we always clear the hover override
  /// before navigating away. Without this the previously-hovered item
  /// stays as `_hoveredItem` while the user is inside the detail
  /// screen, then the dangling state collides with the next rebuild
  /// when the route pops back to Accueil.
  VoidCallback _wrapTapClearingHover(VoidCallback action) {
    return () {
      if (_hoveredItem != null) {
        setState(() => _hoveredItem = null);
      }
      action();
    };
  }

  Widget _content(BuildContext context) {
    final ref = this.ref;
    final continueItems =
        ref.watch(continueWatchingProvider).valueOrNull ?? const [];
    final favs = ref.watch(favoritesProvider).items;
    // Hoist parent props onto local vars so the body code below stays
    // readable (was a free function before this widget went stateful).
    final featured = widget.featured;
    final topInset = widget.topInset;
    final catchupPrograms = widget.catchupPrograms;
    final onPlayItem = widget.onPlayItem;
    final onPlayFavorite = widget.onPlayFavorite;
    final onPlayCatchup = widget.onPlayCatchup;
    final onPlayContinueItem = widget.onPlayContinueItem;

    final liveFavs =
        favs.where((f) => f.mode == 'live').take(10).toList();
    final movieFavs =
        favs.where((f) => f.mode == 'vod').take(10).toList();
    final seriesFavs =
        favs.where((f) => f.mode == 'series').take(10).toList();

    return ListView(
      children: <Widget>[
        // Hero — bleeds under the app bar; emits its current rotation
        // item up so [_AmbientWallpaper] above can sync.
        if (featured.isNotEmpty)
          HomeHero(
            items: featured,
            topInset: topInset,
            onPlayItem: onPlayItem,
            // On Accueil we paint a full-screen ambient wallpaper
            // ourselves (synced to the hero's rotation), so the hero
            // skips its own image to avoid double-painting + the
            // "image seam" the user sees on scroll.
            transparentBackdrop: true,
            onCurrentItemChanged: (item) {
              if (!mounted) return;
              setState(() => _wallpaperItem = item);
            },
          )
        else
          SizedBox(height: topInset),

        // Continue Watching — pulls from provider, mode-agnostic. Items
        // already carry their own URL + resume key, so we open the
        // player directly (no detail-screen detour). Going through
        // detail would mis-route series → episode page with no season
        // info, since Continue Watching stores the *episode* identity.
        ContinueWatchingRow(
          items: continueItems,
          onTap: (item) => _wrapTapClearingHover(
              () => onPlayContinueItem(item))(),
          onItemHover: _onItemHover,
        ),

        if (liveFavs.isNotEmpty)
          _FavoritesShelf(
            title: AppLocalizations.of(context)!.chainesFavorites,
            items: liveFavs,
            onTap: (fav) => _wrapTapClearingHover(
                () => onPlayFavorite(fav))(),
            onHoverChanged: _onItemHover,
            aspectRatio: 1,
            tileWidth: 110,
          ),

        if (movieFavs.isNotEmpty)
          _FavoritesShelf(
            title: AppLocalizations.of(context)!.filmsFavoris,
            items: movieFavs,
            onTap: (fav) => _wrapTapClearingHover(
                () => onPlayFavorite(fav))(),
            onHoverChanged: _onItemHover,
            aspectRatio: 2 / 3,
            tileWidth: 110,
          ),

        if (seriesFavs.isNotEmpty)
          _FavoritesShelf(
            title: AppLocalizations.of(context)!.seriesFavorites,
            items: seriesFavs,
            onTap: (fav) => _wrapTapClearingHover(
                () => onPlayFavorite(fav))(),
            onHoverChanged: _onItemHover,
            aspectRatio: 2 / 3,
            tileWidth: 110,
          ),

        if (catchupPrograms.isNotEmpty)
          CatchupRow(programs: catchupPrograms, onTap: onPlayCatchup),

        if (featured.isNotEmpty)
          RecentlyAddedRow(
            items: featured,
            mode: ContentMode.vod, // non-live so the row renders
            onTap: (item) => _wrapTapClearingHover(
                () => onPlayItem(item))(),
            onItemHover: _onItemHover,
          ),

        SizedBox(height: DS.padding.contentBottom),
      ],
    );
  }

}

/// Horizontal shelf of favourites for one mode (live / films / séries).
/// Title on top, scroll-x row of poster tiles below.
class _FavoritesShelf extends StatelessWidget {
  const _FavoritesShelf({
    required this.title,
    required this.items,
    required this.onTap,
    required this.aspectRatio,
    required this.tileWidth,
    this.onHoverChanged,
  });

  final String title;
  final List<FavoriteItem> items;
  final void Function(FavoriteItem) onTap;
  final double aspectRatio;
  final double tileWidth;

  /// Fires `(fav, true)` on tile-enter, `(fav, false)` on tile-exit.
  /// Used to drive the Accueil's ambient-wallpaper override.
  final void Function(FavoriteItem fav, bool isHovered)? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final tileHeight = tileWidth / aspectRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            DS.padding.screenHorizontal,
            DS.space.md,
            DS.padding.screenHorizontal,
            DS.space.xs,
          ),
          child: Text(
            title,
            style: DSText.title3.copyWith(color: Colors.white),
          ),
        ),
        SizedBox(
          height: tileHeight + 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: DS.padding.screenHorizontal,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: DS.space.sm),
            itemBuilder: (_, i) => _FavoriteTile(
              fav: items[i],
              width: tileWidth,
              height: tileHeight,
              onTap: () => onTap(items[i]),
              onHoverChanged: onHoverChanged == null
                  ? null
                  : (h) => onHoverChanged!(items[i], h),
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteTile extends StatefulWidget {
  const _FavoriteTile({
    required this.fav,
    required this.width,
    required this.height,
    required this.onTap,
    this.onHoverChanged,
  });

  final FavoriteItem fav;
  final double width;
  final double height;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  bool _hovered = false;

  void _setHover(bool v) {
    if (_hovered == v || !mounted) return;
    // Guard against navigation race: when the user taps the tile, the
    // route changes before MouseRegion.onExit fires on this card.
    // Setting state on an inactive element trips the framework
    // assertion `_elements.contains(element)`. Skip if our route is
    // not the topmost.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    setState(() => _hovered = v);
    widget.onHoverChanged?.call(v);
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
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedScale(
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
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radius.card),
                    child: SizedBox(
                      width: widget.width,
                      height: widget.height,
                      // Live channels ship landscape logos that don't
                      // match the square (aspectRatio: 1) tile of the
                      // "Chaînes favorites" shelf — `BoxFit.cover`
                      // crops them aggressively (BeIN/CANAL+ sliced).
                      // Letterbox via `BoxFit.contain` over the dark
                      // surface; keep `cover` for poster modes.
                      child: Container(
                        color: AppColors.darkSurface,
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
                                  widget.fav.mode == 'live'
                                      ? Icons.live_tv
                                      : widget.fav.mode == 'series'
                                          ? Icons.tv
                                          : Icons.movie,
                                  color: DS.colour.textTertiary,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.darkSurface,
                              child: Icon(
                                widget.fav.mode == 'live'
                                    ? Icons.live_tv
                                    : widget.fav.mode == 'series'
                                        ? Icons.tv
                                        : Icons.movie,
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
      ),
    );
  }
}
