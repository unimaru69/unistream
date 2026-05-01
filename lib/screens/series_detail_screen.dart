import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/skeleton_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/cache_config.dart';
import '../models/episode.dart';
import '../models/favorite_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/watch_progress_provider.dart';
import '../repositories/content_repository.dart';
import '../models/next_episode_info.dart';
import '../providers/tmdb_provider.dart';
import '../services/tmdb_service.dart';
import '../utils/routes.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/plex_backdrop.dart';
import '../widgets/tmdb_badge.dart';
import '../widgets/tmdb_cast_row.dart';
import '../widgets/tmdb_trailer_button.dart';
import 'player/player_screen.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final String seriesId;
  final String title;
  final String cover;
  final String? rating;
  final String? categoryName;
  final String? plot;
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.title,
    required this.cover,
    this.rating,
    this.categoryName,
    this.plot,
  });
  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  WatchProgressActions get _wp => ref.read(watchProgressActionsProvider);
  Map<String, List<Episode>> _episodes = {};
  List<String> _seasons = [];
  String? _selectedSeason;
  bool _loading = true;
  String? _error;

  String get _favKey => 'series:${widget.seriesId}';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final episodesMap = await _repo.getSeriesEpisodes(widget.seriesId);
      final seasons = episodesMap.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      setState(() {
        _episodes = episodesMap;
        _seasons  = seasons;
        _selectedSeason = seasons.isNotEmpty ? seasons.first : null;
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Mark all episodes before [ep] in the current season as watched.
  /// Returns the list of episode IDs that were actually marked (for undo).
  Future<List<String>> _markPreviousAsWatched(Episode ep) async {
    if (_selectedSeason == null) return [];
    final eps = _episodes[_selectedSeason!] ?? [];
    final idx = eps.indexWhere((e) => e.idStr == ep.idStr);
    if (idx <= 0) return [];

    final marked = <String>[];
    for (var i = 0; i < idx; i++) {
      final prev = eps[i];
      final prevId = prev.idStr;
      final pos = await _wp.getPosition(prevId);
      if (pos == null || pos.inSeconds < 30) {
        await _wp.save(prevId, const Duration(minutes: 57), const Duration(hours: 1));
        await _wp.saveMeta(prevId, prev.displayTitle, widget.cover, '', 'series');
        marked.add(prevId);
      }
    }
    return marked;
  }

  /// Undo auto-marking: clear progress for the given episode IDs.
  Future<void> _undoMarkAsWatched(List<String> episodeIds) async {
    for (final id in episodeIds) {
      await _wp.clear(id);
    }
  }

  /// Mark a single episode as watched or unwatched (context menu).
  Future<void> _toggleEpisodeWatched(Episode ep) async {
    final prog = await _wp.getPosition(ep.idStr);
    final isWatched = prog != null && prog.inSeconds > 30;
    if (isWatched) {
      await _wp.clear(ep.idStr);
    } else {
      await _wp.save(ep.idStr, const Duration(minutes: 57), const Duration(hours: 1));
      await _wp.saveMeta(ep.idStr, ep.displayTitle, widget.cover, '', 'series');
    }
  }

  void _showEpisodeContextMenu(Episode ep, Offset position) {
    final l10n = AppLocalizations.of(context)!;
    final tc = AppThemeColors.of(context);
    final progress = ref.read(watchProgressProvider).valueOrNull ?? {};
    final prog = progress[ep.idStr];
    final isWatched = prog != null && prog > 0.95;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: tc.surface,
      items: [
        PopupMenuItem(
          value: 'toggle',
          child: Row(children: [
            Icon(isWatched ? Icons.visibility_off : Icons.check_circle,
                size: 18, color: isWatched ? tc.textSecondary : Colors.green),
            const SizedBox(width: 8),
            Text(isWatched ? l10n.marquerNonVu : l10n.marquerVu,
                style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'toggle') _toggleEpisodeWatched(ep);
    });
  }

  void _playEpisode(Episode ep) {
    final epId = ep.idStr;
    final url = _repo.getSeriesEpisodeUrl(epId, ep.containerExtension);
    _wp.saveMeta(epId, ep.displayTitle, widget.cover, url, 'series');
    _wp.saveHistory('series:$epId', ep.displayTitle, widget.cover, url, 'series');

    // Mark previous episodes as watched + show undo snackbar
    _markPreviousAsWatched(ep).then((marked) {
      if (marked.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.episodesMarquesVus(marked.length),
          actionLabel: AppLocalizations.of(context)!.annuler,
          onAction: () => _undoMarkAsWatched(marked),
        );
      }
    });

    // Find next episode in same season
    NextEpisodeInfo? nextEp;
    if (_selectedSeason != null) {
      final eps = _episodes[_selectedSeason!] ?? [];
      final idx = eps.indexWhere((e) => e.idStr == epId);
      if (idx >= 0 && idx < eps.length - 1) {
        final next = eps[idx + 1];
        nextEp = NextEpisodeInfo(
          id: next.idStr,
          title: next.displayTitle,
          containerExtension: next.containerExtension,
          coverUrl: widget.cover,
        );
      }
    }

    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: ep.displayTitle,
      resumeKey: epId,
      coverUrl: widget.cover,
      nextEpisode: nextEp,
    ))).then((_) {
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(watchProgressProvider).valueOrNull ?? {};
    final favState = ref.watch(favoritesProvider);
    final wlState = ref.watch(watchlistProvider);
    final isFav = favState.keys.contains(_favKey);
    final isWl = wlState.keys.contains(_favKey);
    final sourceSynopsis = widget.plot ?? '';
    final needsEnrichment = sourceSynopsis.trim().isEmpty;
    final tmdbCfg = ref.watch(tmdbConfigProvider);
    final tmdbAsync = tmdbCfg.isActive
        ? ref.watch(tmdbLookupProvider(TmdbLookup(
            rawTitle: widget.title,
            kind: TmdbKind.tv,
          )))
        : const AsyncValue<TmdbResult?>.data(null);
    final tmdb = tmdbAsync.valueOrNull;
    final synopsis =
        needsEnrichment ? (tmdb?.overview ?? '') : sourceSynopsis;
    // Don't flash the source poster while TMDB is still loading — keep the
    // backdrop empty so PlexBackdrop stays dark, then fade in once data
    // settles. Falls back to the source only after TMDB confirms a miss.
    final tmdbBackdrop = TmdbService.image(tmdb?.backdropPath, size: 'original');
    final String backdropUrl;
    if (tmdbBackdrop != null) {
      backdropUrl = tmdbBackdrop;
    } else if (tmdbAsync.isLoading) {
      backdropUrl = '';
    } else {
      backdropUrl = widget.cover;
    }
    // High-resolution TMDB poster for the left-panel hero (480×600). Source
    // IPTV posters are typically w185–w300 and look pixelated at this size.
    final tmdbPoster = TmdbService.image(tmdb?.posterPath, size: 'w780');
    final String posterUrl = tmdbPoster ?? widget.cover;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Plex-style blurred backdrop — use TMDB's wide backdrop when
          // available, fall back to the source poster.
          PlexBackdrop(imageUrl: backdropUrl),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (!isWide) {
              return _buildNarrowLayout(
                tc: tc,
                l10n: l10n,
                progress: progress,
                isFav: isFav,
                isWl: isWl,
                synopsis: synopsis,
                sourceSynopsis: sourceSynopsis,
                needsEnrichment: needsEnrichment,
                tmdbAsync: tmdbAsync,
                tmdb: tmdb,
                posterUrl: posterUrl,
              );
            }
            return Row(children: [
        // Left panel: poster + metadata + seasons
        SizedBox(
          // 360 instead of 260 so the synopsis breathes (5-line truncation
          // on 260 px made the text unreadable) and the cast row can show
          // more than two avatars before scroll.
          width: 480,
          child: CustomScrollView(
            slivers: [
              // Poster — prefer the TMDB w780 image so the hero isn't
              // pixelated; falls back to the IPTV source when unavailable.
              SliverToBoxAdapter(
                child: posterUrl.isNotEmpty
                    ? Stack(children: [
                        CachedNetworkImage(
                          imageUrl: posterUrl,
                          cacheManager: AppCacheManager.instance,
                          width: 480, height: 600, fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => SizedBox(height: 600, child: ColoredBox(color: tc.inputFill)),
                          errorWidget: (_, __, ___) => SizedBox(
                            height: 600,
                            child: Container(color: tc.inputFill,
                                child: Icon(Icons.tv, size: 48, color: tc.borderColor)),
                          ),
                        ),
                        // Gradient scrim
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, tc.surface],
                              ),
                            ),
                          ),
                        ),
                        // Back button
                        Positioned(top: 8, left: 8,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: Colors.black38),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: l10n.retour,
                          ),
                        ),
                      ])
                    : Stack(children: [
                        Container(height: 200, color: tc.inputFill,
                            child: Icon(Icons.tv, size: 48, color: tc.borderColor)),
                        Positioned(top: 8, left: 8,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: tc.textSecondary),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: l10n.retour,
                          ),
                        ),
                      ]),
              ),

              // Title + metadata
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Title — always white because the Plex backdrop is dark.
                    Text(widget.title, style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                    )),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, runSpacing: 4, children: [
                      if (widget.rating != null && widget.rating!.isNotEmpty && widget.rating != '0')
                        _MetaChip(icon: Icons.star, label: widget.rating!, color: Colors.amber),
                      if (widget.categoryName != null && widget.categoryName!.isNotEmpty)
                        _MetaChip(
                          icon: Icons.category,
                          label: widget.categoryName!,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      if (_seasons.isNotEmpty)
                        _MetaChip(
                          icon: Icons.layers,
                          label: '${_seasons.length} ${l10n.saisons.toLowerCase()}',
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                    ]),
                    const SizedBox(height: 12),

                    // Favorite / Watchlist buttons
                    Row(children: [
                      IconButton(
                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : tc.textSecondary),
                        tooltip: l10n.favoris,
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggle(_favKey, FavoriteItem(
                            key: _favKey, name: widget.title, cover: widget.cover,
                            mode: 'series', seriesId: widget.seriesId,
                          ));
                        },
                      ),
                      IconButton(
                        icon: Icon(isWl ? Icons.bookmark : Icons.bookmark_border,
                            color: isWl ? AppColors.primaryBlue : tc.textSecondary),
                        tooltip: l10n.aRegarder,
                        onPressed: () {
                          ref.read(watchlistProvider.notifier).toggle(_favKey, FavoriteItem(
                            key: _favKey, name: widget.title, cover: widget.cover,
                            mode: 'series', seriesId: widget.seriesId,
                          ));
                        },
                      ),
                    ]),

                    // Synopsis — white on dark backdrop. Falls back to TMDB
                    // when the source has none.
                    if (tmdbAsync.isLoading && sourceSynopsis.isEmpty) ...[
                      const SizedBox(height: 12),
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ] else if (synopsis.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Text(synopsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.80),
                                height: 1.4,
                              )),
                        ),
                      ]),
                      if (needsEnrichment) ...[
                        const SizedBox(height: 6),
                        const TmdbBadge(),
                      ],
                    ],

                    if (tmdb != null && tmdb.videos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TmdbTrailerButton(videos: tmdb.videos),
                    ],
                    if (tmdb != null && tmdb.cast.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        const Text('Distribution',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(width: 8),
                        const TmdbBadge(),
                      ]),
                      const SizedBox(height: 6),
                      TmdbCastRow(cast: tmdb.cast),
                    ],
                    const SizedBox(height: 16),

                    // Seasons header.
                    Text(l10n.saisons.toUpperCase(), style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                    const SizedBox(height: 4),
                  ]),
                ),
              ),

              // Season list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final s = _seasons[i];
                    final sel = _selectedSeason == s;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      child: ListTile(
                        dense: true,
                        title: Text(l10n.saison(s), style: TextStyle(fontSize: 13,
                            color: sel ? tc.textPrimary : tc.textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                        selected: sel,
                        selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () => setState(() => _selectedSeason = s),
                      ),
                    );
                  },
                  childCount: _seasons.length,
                ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: tc.divider),

        // Right panel: episodes
        Expanded(
          child: _loading
              ? const SkeletonList(count: 6)
              : _error != null
              ? Center(child: Text('${l10n.erreur}: $_error', style: const TextStyle(color: Colors.red)))
              : _selectedSeason == null
              ? Center(child: Text(l10n.selectionneSaison,
                  style: TextStyle(color: tc.textDisabled)))
              : RefreshIndicator(
                  onRefresh: _loadInfo,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _episodes[_selectedSeason]?.length ?? 0,
                    itemBuilder: (_, i) {
                      final ep = _episodes[_selectedSeason]![i];
                      final epNum = ep.number != 0 ? ep.number : i + 1;
                      final title = ep.displayTitle;
                      final prog = progress[ep.idStr];
                      final bool isWatched = prog != null && prog > 0.95;
                      final bool isPartial = prog != null && prog <= 0.95;
                      final bool isNew = prog == null;
                      return GestureDetector(
                        onSecondaryTapUp: (details) => _showEpisodeContextMenu(ep, details.globalPosition),
                        onLongPressStart: (details) => _showEpisodeContextMenu(ep, details.globalPosition),
                        child: ListTile(
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isWatched
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : AppColors.primaryBlue.withValues(alpha: 0.2),
                                child: isWatched
                                    ? const Icon(Icons.check, size: 16, color: Colors.green)
                                    : Text('$epNum',
                                        style: TextStyle(fontSize: 12, color: tc.textSecondary)),
                              ),
                              if (isNew)
                                Positioned(top: -2, right: -2,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(title, style: TextStyle(fontSize: 14,
                              color: isWatched ? tc.textDisabled : tc.textPrimary)),
                          subtitle: isPartial
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: LinearProgressIndicator(
                                    value: prog,
                                    backgroundColor: tc.divider,
                                    color: Colors.amber, minHeight: 3,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                              : isWatched
                              ? Text(l10n.vu, style: const TextStyle(fontSize: 11, color: Colors.green))
                              : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          hoverColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                          onTap: () => _playEpisode(ep),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]);
          }),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout({
    required AppThemeColors tc,
    required AppLocalizations l10n,
    required Map<String, double> progress,
    required bool isFav,
    required bool isWl,
    required String synopsis,
    required String sourceSynopsis,
    required bool needsEnrichment,
    required AsyncValue<TmdbResult?> tmdbAsync,
    required TmdbResult? tmdb,
    required String posterUrl,
  }) {
    final episodes = _selectedSeason != null
        ? (_episodes[_selectedSeason!] ?? const <Episode>[])
        : const <Episode>[];

    return CustomScrollView(
      slivers: [
        // Hero poster as a tall pinned-back app bar.
        SliverAppBar(
          expandedHeight: 420,
          pinned: false,
          backgroundColor: Colors.transparent,
          leading: BackButton(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: posterUrl.isNotEmpty
                ? Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(
                      imageUrl: posterUrl,
                      cacheManager: AppCacheManager.instance,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => ColoredBox(color: tc.inputFill),
                      errorWidget: (_, __, ___) => Container(
                        color: tc.inputFill,
                        child: Icon(Icons.tv, size: 48, color: tc.borderColor),
                      ),
                    ),
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, tc.surface],
                          ),
                        ),
                      ),
                    ),
                  ])
                : Container(color: tc.inputFill,
                    child: Icon(Icons.tv, size: 48, color: tc.borderColor)),
          ),
        ),
        // Title + chips + actions + synopsis + cast.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              )),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 4, children: [
                if (widget.rating != null && widget.rating!.isNotEmpty && widget.rating != '0')
                  _MetaChip(icon: Icons.star, label: widget.rating!, color: Colors.amber),
                if (widget.categoryName != null && widget.categoryName!.isNotEmpty)
                  _MetaChip(
                    icon: Icons.category,
                    label: widget.categoryName!,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                if (_seasons.isNotEmpty)
                  _MetaChip(
                    icon: Icons.layers,
                    label: '${_seasons.length} ${l10n.saisons.toLowerCase()}',
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.white70),
                  tooltip: l10n.favoris,
                  onPressed: () {
                    ref.read(favoritesProvider.notifier).toggle(_favKey, FavoriteItem(
                      key: _favKey, name: widget.title, cover: widget.cover,
                      mode: 'series', seriesId: widget.seriesId,
                    ));
                  },
                ),
                IconButton(
                  icon: Icon(isWl ? Icons.bookmark : Icons.bookmark_border,
                      color: isWl ? AppColors.primaryBlue : Colors.white70),
                  tooltip: l10n.aRegarder,
                  onPressed: () {
                    ref.read(watchlistProvider.notifier).toggle(_favKey, FavoriteItem(
                      key: _favKey, name: widget.title, cover: widget.cover,
                      mode: 'series', seriesId: widget.seriesId,
                    ));
                  },
                ),
              ]),
              if (tmdbAsync.isLoading && sourceSynopsis.isEmpty) ...[
                const SizedBox(height: 12),
                const SizedBox(height: 14, width: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5)),
              ] else if (synopsis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(synopsis, style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                )),
                if (needsEnrichment) ...[
                  const SizedBox(height: 6),
                  const TmdbBadge(),
                ],
              ],
              if (tmdb != null && tmdb.videos.isNotEmpty) ...[
                const SizedBox(height: 12),
                TmdbTrailerButton(videos: tmdb.videos),
              ],
              if (tmdb != null && tmdb.cast.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Text('Distribution',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const TmdbBadge(),
                ]),
                const SizedBox(height: 6),
                TmdbCastRow(cast: tmdb.cast),
              ],
              const SizedBox(height: 16),
              if (_seasons.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _seasons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final s = _seasons[i];
                      final sel = _selectedSeason == s;
                      return ChoiceChip(
                        label: Text(l10n.saison(s),
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.white70,
                                fontSize: 12)),
                        selected: sel,
                        backgroundColor: Colors.white12,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.7),
                        onSelected: (_) => setState(() => _selectedSeason = s),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        // Episodes list.
        if (_loading)
          const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(24),
                  child: SkeletonList(count: 6))),
        if (!_loading && _error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${l10n.erreur}: $_error',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        if (!_loading && _error == null && _selectedSeason == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.selectionneSaison,
                  style: TextStyle(color: tc.textDisabled))),
            ),
          ),
        if (!_loading && _error == null && _selectedSeason != null)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final ep = episodes[i];
                final epNum = ep.number != 0 ? ep.number : i + 1;
                final title = ep.displayTitle;
                final prog = progress[ep.idStr];
                final bool isWatched = prog != null && prog > 0.95;
                final bool isPartial = prog != null && prog <= 0.95;
                final bool isNew = prog == null;
                return GestureDetector(
                  onSecondaryTapUp: (details) => _showEpisodeContextMenu(ep, details.globalPosition),
                  onLongPressStart: (details) => _showEpisodeContextMenu(ep, details.globalPosition),
                  child: ListTile(
                    leading: Stack(clipBehavior: Clip.none, children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isWatched
                            ? Colors.green.withValues(alpha: 0.2)
                            : AppColors.primaryBlue.withValues(alpha: 0.2),
                        child: isWatched
                            ? const Icon(Icons.check, size: 16, color: Colors.green)
                            : Text('$epNum',
                                style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ),
                      if (isNew)
                        Positioned(top: -2, right: -2,
                          child: Container(width: 10, height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue, shape: BoxShape.circle))),
                    ]),
                    title: Text(title, style: TextStyle(fontSize: 14,
                        color: isWatched ? Colors.white38 : Colors.white)),
                    subtitle: isPartial
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: LinearProgressIndicator(
                              value: prog,
                              backgroundColor: Colors.white12,
                              color: Colors.amber, minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )
                        : isWatched
                            ? Text(l10n.vu, style: const TextStyle(fontSize: 11, color: Colors.green))
                            : null,
                    onTap: () => _playEpisode(ep),
                  ),
                );
              },
              childCount: episodes.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ]);
  }
}
