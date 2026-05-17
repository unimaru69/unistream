import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/design_tokens.dart';
import 'package:unistream/core/typography.dart';
import 'package:unistream/l10n/app_localizations.dart';

import '../models/content_mode.dart';
import '../models/episode.dart';
import '../models/favorite_item.dart';
import '../models/next_episode_info.dart';
import '../providers/favorites_provider.dart';
import '../providers/tmdb_provider.dart';
import '../providers/watch_progress_provider.dart';
import '../repositories/content_repository.dart';
import '../services/tmdb_service.dart';
import '../utils/content_key.dart';
import '../utils/routes.dart';
import '../utils/snackbar_helper.dart';
import '../utils/title_formatting.dart';
import '../widgets/hero_buttons.dart';
import '../widgets/plex_backdrop.dart';
import 'home/widgets/collection_dialogs.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/tmdb_badge.dart';
import '../widgets/tmdb_cast_row.dart';
import '../widgets/tmdb_trailer_button.dart';
import 'player/player_screen.dart';
import 'player/widgets/resume_confirm_dialog.dart';

/// Apple-TV+-style series detail. Mirrors
/// `tvos/UniStreamTV/UniStreamTV/Views/Series/SeriesDetailView.swift`:
/// full-bleed sharp backdrop, hero block (title + meta strip +
/// synopsis + smart "Reprendre/Démarrer/Revoir" CTA), horizontal
/// season chips, vertical episode list with thumbnails, cast row.
///
/// Per-episode TMDB stills + synopses are not yet wired (the Flutter
/// `TmdbService` doesn't expose `fetchSeason` like its Swift sibling)
/// — episodes use the series poster as fallback thumbnail. Wire that
/// up when the service grows the season endpoint.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.title,
    required this.cover,
    this.rating,
    this.categoryName,
    this.plot,
  });

  final String seriesId;
  final String title;
  final String cover;
  final String? rating;
  final String? categoryName;
  final String? plot;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  WatchProgressActions get _wp => ref.read(watchProgressActionsProvider);

  Map<String, List<Episode>> _episodes = const {};
  List<String> _seasons = const [];
  String? _selectedSeason;
  bool _loading = true;
  String? _error;

  /// Bare seriesId — same key tvOS uses for the favourite blob.
  String get _favKey => widget.seriesId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final episodes = await _repo.getSeriesEpisodes(widget.seriesId);
      final seasons = episodes.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _seasons = seasons;
        _selectedSeason = seasons.isNotEmpty ? seasons.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Episode actions ──────────────────────────────────────────────

  String _episodeKey(Episode ep) => ContentKey.make(ContentKey.episode, ep.idStr);

  /// `>= 0.95` (not `>`) so the manual "Marquer vu" marker — which
  /// stores ratio = 0.95 exactly (57 min / 60 min, the largest value
  /// `WatchProgress.save` keeps without auto-clearing) — counts as
  /// watched. Without this, marking an episode looked stuck at "95 %
  /// in progress" and the smart CTA never advanced to the next
  /// episode.
  bool _isWatched(double? ratio) => ratio != null && ratio >= 0.95;
  bool _isInProgress(double? ratio) =>
      ratio != null && ratio > 0.005 && ratio < 0.95;

  /// Walk every episode across every season in order and pick the
  /// highest-ordered one that has progress. Closest cheap proxy for
  /// "most recently watched" without an explicit `updatedAt` on the
  /// Flutter watch-progress store.
  ({String season, Episode episode, double ratio})? _resumeTarget(
    Map<String, double> progress,
  ) {
    ({String season, Episode episode, double ratio})? best;
    for (final season in _seasons) {
      for (final ep in _episodes[season] ?? const <Episode>[]) {
        final ratio = progress[_episodeKey(ep)];
        if (ratio == null || ratio <= 0.005) continue;
        best = (season: season, episode: ep, ratio: ratio);
      }
    }
    return best;
  }

  Episode? _nextEpisodeInSeason(String season, Episode current) {
    final list = _episodes[season] ?? const <Episode>[];
    final idx = list.indexWhere((e) => e.idStr == current.idStr);
    if (idx < 0 || idx + 1 >= list.length) return null;
    return list[idx + 1];
  }

  Episode? _firstEpisode() {
    final season = _seasons.isNotEmpty ? _seasons.first : null;
    if (season == null) return null;
    final eps = _episodes[season];
    if (eps == null || eps.isEmpty) return null;
    return eps.first;
  }

  /// Mark all episodes before [ep] in [season] as watched.
  /// Returns the keys we actually marked (so undo can clear them).
  Future<List<String>> _markPreviousAsWatched(Episode ep, String season) async {
    final eps = _episodes[season] ?? const <Episode>[];
    final idx = eps.indexWhere((e) => e.idStr == ep.idStr);
    if (idx <= 0) return const <String>[];

    final marked = <String>[];
    for (var i = 0; i < idx; i++) {
      final prev = eps[i];
      final key = _episodeKey(prev);
      final pos = await _wp.getPosition(key);
      if (pos == null || pos.inSeconds < 30) {
        await _wp.saveMeta(
          key,
          prev.displayTitle,
          widget.cover,
          '',
          'series',
        );
        await _wp.save(key, const Duration(minutes: 57), const Duration(hours: 1));
        marked.add(key);
      }
    }
    return marked;
  }

  Future<void> _undoMarkAsWatched(List<String> keys) async {
    for (final key in keys) {
      await _wp.clear(key);
    }
  }

  Future<void> _toggleWatched(Episode ep) async {
    final key = _episodeKey(ep);
    final pos = await _wp.getPosition(key);
    final wasWatched = pos != null && pos.inSeconds > 30;
    if (wasWatched) {
      await _wp.clear(key);
    } else {
      await _wp.saveMeta(key, ep.displayTitle, widget.cover, '', 'series');
      await _wp.save(key, const Duration(minutes: 57), const Duration(hours: 1));
    }
  }

  /// Mark every episode in [season] as watched, or clear them all if
  /// they're already watched. Triggered by right-click / long-press on
  /// the season chip.
  Future<void> _toggleSeasonWatched(String season) async {
    final eps = _episodes[season] ?? const <Episode>[];
    if (eps.isEmpty) return;
    final progress = ref.read(watchProgressProvider).valueOrNull ??
        const <String, double>{};
    final allWatched =
        eps.every((e) => _isWatched(progress[_episodeKey(e)]));
    for (final ep in eps) {
      final key = _episodeKey(ep);
      if (allWatched) {
        await _wp.clear(key);
      } else {
        await _wp.saveMeta(key, ep.displayTitle, widget.cover, '', 'series');
        await _wp.save(
          key,
          const Duration(minutes: 57),
          const Duration(hours: 1),
        );
      }
    }
  }

  /// Resolve the season this episode belongs to.
  String? _seasonOf(Episode ep) {
    for (final s in _seasons) {
      if ((_episodes[s] ?? const <Episode>[])
          .any((e) => e.idStr == ep.idStr)) {
        return s;
      }
    }
    return _selectedSeason;
  }

  /// Always passes `resumeKey: epKey` so the player saves progress as
  /// you watch — without that the player throws away every position
  /// update on exit (player_screen.dart:415/606/722). The optional
  /// `restart` flag clears any saved progress first so "Revoir" /
  /// "Lecture E(next)" start from 0.
  Future<void> _playEpisode(
    Episode ep, {
    bool restart = false,
    bool confirmIfResume = false,
  }) async {
    final key = _episodeKey(ep);

    // Row taps land here with [confirmIfResume]: true so the user gets
    // an explicit Reprendre / Recommencer choice when they tap an
    // episode that already has progress. Smart-CTA call-sites
    // ("Reprendre E5", "Lecture E6", "Démarrer S1E1") skip this — the
    // copy on the button already encodes the user's intent.
    if (confirmIfResume && !restart) {
      final saved = await _wp.getProgress(key);
      final pos = saved.position;
      final dur = saved.duration;
      final ratio = (pos != null && dur != null && dur.inSeconds > 0)
          ? pos.inSeconds / dur.inSeconds
          : 0.0;
      if (pos != null && pos.inSeconds > 30 && ratio < 0.95) {
        if (!mounted) return;
        final choice = await showResumeConfirmDialog(
          context: context,
          title: ep.displayTitle,
          position: pos,
          duration: dur,
        );
        if (!mounted) return;
        if (choice == null || choice == ResumeChoice.cancel) return;
        if (choice == ResumeChoice.restart) restart = true;
      }
    }

    if (restart) {
      await _wp.clear(key);
      if (!mounted) return;
    }

    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    final l10n = AppLocalizations.of(context)!;
    final url = _repo.getSeriesEpisodeUrl(ep.idStr, ep.containerExtension);
    _wp.saveMeta(key, ep.displayTitle, widget.cover, url, 'series');
    _wp.saveHistory(key, ep.displayTitle, widget.cover, url, 'series');

    // Mark earlier episodes in the same season as watched + offer undo.
    final season = _seasonOf(ep);
    if (season != null) {
      _markPreviousAsWatched(ep, season).then((marked) {
        if (marked.isEmpty || !mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        showAppSnackBar(
          context,
          l10n.episodesMarquesVus(marked.length),
          actionLabel: l10n.annuler,
          onAction: () => _undoMarkAsWatched(marked),
        );
      });
    }

    NextEpisodeInfo? next;
    if (season != null) {
      final nextEp = _nextEpisodeInSeason(season, ep);
      if (nextEp != null) {
        next = NextEpisodeInfo(
          id: nextEp.idStr,
          title: nextEp.displayTitle,
          containerExtension: nextEp.containerExtension,
          coverUrl: widget.cover,
        );
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      slideRoute(PlayerScreen(
        url: url,
        title: ep.displayTitle,
        resumeKey: key,
        coverUrl: widget.cover,
        nextEpisode: next,
      )),
    );
  }

  // ── Smart hero CTA ───────────────────────────────────────────────

  ({String label, IconData icon, VoidCallback action})? _primaryCta(
    Map<String, double> progress,
  ) {
    final resume = _resumeTarget(progress);
    if (resume != null) {
      final epNum = resume.episode.number;
      if (_isWatched(resume.ratio)) {
        // Last watched fully — chain to the next episode if any,
        // otherwise offer "Revoir" from the start.
        final next = _nextEpisodeInSeason(resume.season, resume.episode);
        if (next != null) {
          final nextNum = next.number;
          return (
            label: AppLocalizations.of(context)!.lectureEp(nextNum),
            icon: Icons.play_arrow,
            action: () => _playEpisode(next, restart: true),
          );
        }
        return (
          label: AppLocalizations.of(context)!.revoir,
          icon: Icons.replay,
          action: () => _playEpisode(resume.episode, restart: true),
        );
      }
      return (
        label: AppLocalizations.of(context)!.reprendreEp(epNum),
        icon: Icons.play_arrow,
        action: () => _playEpisode(resume.episode),
      );
    }
    final first = _firstEpisode();
    if (first != null) {
      final season = _seasons.first;
      return (
        label: AppLocalizations.of(context)!.demarrerSE(season, first.number),
        icon: Icons.play_arrow,
        action: () => _playEpisode(first, restart: true),
      );
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(watchProgressProvider).valueOrNull ??
        const <String, double>{};
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

    // Sharp backdrop with staged fallback: TMDB > nothing-while-loading >
    // source poster (avoids the low-res flash before TMDB resolves).
    final tmdbBackdrop =
        TmdbService.image(tmdb?.backdropPath, size: 'original');
    final String backdropUrl;
    if (tmdbBackdrop != null) {
      backdropUrl = tmdbBackdrop;
    } else if (tmdbAsync.isLoading) {
      backdropUrl = '';
    } else {
      backdropUrl = widget.cover;
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final heroOffset = (viewportHeight * 0.38).clamp(140.0, 420.0);

    final cleanedTitle = widget.title.cleanedTitleNoYear;
    final fallbackTitle = cleanedTitle.isEmpty ? l10n.sansTitre : cleanedTitle;

    final cta = _primaryCta(progress);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PlexBackdrop(imageUrl: backdropUrl, blurSigma: 0),

          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: DS.padding.contentBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: heroOffset),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DS.padding.screenHorizontal,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: _Hero(
                      title: fallbackTitle,
                      synopsis: synopsis,
                      synopsisFromTmdb:
                          needsEnrichment && synopsis.isNotEmpty,
                      isLoadingTmdb: tmdbAsync.isLoading,
                      tmdb: tmdb,
                      providerRating: widget.rating,
                      seasonsCount: _seasons.length,
                      cta: cta,
                      isFav: isFav,
                      isWl: isWl,
                      onToggleFav: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(_favKey, _favItem()),
                      onToggleWl: () => ref
                          .read(watchlistProvider.notifier)
                          .toggle(_favKey, _favItem()),
                      onAddToCollection: () => addToCollectionFlow(
                        context,
                        ref,
                        mode: ContentMode.series,
                        item: _favItem(),
                      ),
                    ),
                  ),
                ),

                if (_seasons.length > 1) ...<Widget>[
                  SizedBox(height: DS.padding.sectionGap),
                  _SeasonChips(
                    seasons: _seasons,
                    selectedSeason: _selectedSeason,
                    watchedCounter: _watchedCount,
                    totalCounter: _totalCount,
                    onSelect: (s) => setState(() => _selectedSeason = s),
                    onLongPress: (s, position) =>
                        _showSeasonMenu(s, position),
                  ),
                ],

                SizedBox(height: DS.space.lg),
                _episodesSection(l10n, progress, tmdb?.id),

                if (tmdb != null && tmdb.cast.isNotEmpty) ...<Widget>[
                  SizedBox(height: DS.padding.sectionGap),
                  _CastSection(cast: tmdb.cast),
                ],

                if (tmdb != null && tmdb.videos.isNotEmpty) ...<Widget>[
                  SizedBox(height: DS.space.lg),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: DS.padding.screenHorizontal,
                    ),
                    child: TmdbTrailerButton(videos: tmdb.videos),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _watchedCount(String season) {
    final progress = ref.read(watchProgressProvider).valueOrNull ??
        const <String, double>{};
    final eps = _episodes[season] ?? const <Episode>[];
    return eps.where((e) => _isWatched(progress[_episodeKey(e)])).length;
  }

  int _totalCount(String season) =>
      (_episodes[season] ?? const <Episode>[]).length;

  void _showSeasonMenu(String season, Offset globalPosition) {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.read(watchProgressProvider).valueOrNull ??
        const <String, double>{};
    final eps = _episodes[season] ?? const <Episode>[];
    final allWatched =
        eps.isNotEmpty && eps.every((e) => _isWatched(progress[_episodeKey(e)]));

    // Anchor on the click point, but pass the overlay size so
    // `showMenu` can flip the menu sideways when the click lands near
    // a screen edge — without that hint Flutter pins the menu's left
    // edge at the click and the content overflows.
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    final menuPos = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlaySize,
    );

    showMenu<String>(
      context: context,
      position: menuPos,
      color: AppColors.darkSurface,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'toggle',
          // Single Text child on purpose: in Material 3 PopupMenuItem
          // wraps its child in a ListTile whose internal Row clamps to
          // ~256 px and is `mainAxisSize.max`, so an Icon + Text Row
          // here overflows by ~10 px on every dark-themed install.
          child: Text(
            allWatched ? l10n.toutMarquerNonVu : l10n.toutMarquerVu,
            style: DSText.body.copyWith(color: Colors.white),
          ),
        ),
      ],
    ).then((v) {
      if (v == 'toggle') _toggleSeasonWatched(season);
    });
  }

  Widget _episodesSection(
    AppLocalizations l10n,
    Map<String, double> progress,
    int? tmdbId,
  ) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        child: const SkeletonList(count: 4, shrinkWrap: true),
      );
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        child: Text(
          '${l10n.erreur}: $_error',
          style: DSText.body.copyWith(color: AppColors.error),
        ),
      );
    }
    final season = _selectedSeason;
    if (season == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        child: Text(
          l10n.selectionneSaison,
          style: DSText.body.copyWith(color: DS.colour.textTertiary),
        ),
      );
    }
    final episodes = _episodes[season] ?? const <Episode>[];
    if (episodes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        child: Text(
          l10n.aucunEpisode,
          style: DSText.body.copyWith(color: DS.colour.textTertiary),
        ),
      );
    }

    // Resolve per-episode TMDB metadata (stills + synopsis) when both
    // a TMDB id and a parseable season number are available. Failure
    // returns an empty map so the row falls back gracefully on the
    // series poster + provider title.
    final seasonNum = int.tryParse(season);
    final Map<int, EpisodeMeta> meta;
    if (tmdbId != null && seasonNum != null) {
      meta = ref
              .watch(tmdbSeasonProvider(TmdbSeasonKey(
                tmdbId: tmdbId,
                seasonNumber: seasonNum,
              )))
              .valueOrNull ??
          const <int, EpisodeMeta>{};
    } else {
      meta = const <int, EpisodeMeta>{};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
          child: Text(
            l10n.saison(season),
            style: DSText.title1.copyWith(color: Colors.white),
          ),
        ),
        SizedBox(height: DS.space.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: DS.padding.screenHorizontal,
            ),
            itemCount: episodes.length,
            separatorBuilder: (_, __) => SizedBox(height: DS.space.sm),
            itemBuilder: (_, i) {
              final ep = episodes[i];
              final ratio = progress[_episodeKey(ep)];
              return _EpisodeRow(
                episode: ep,
                season: season,
                cover: widget.cover,
                meta: meta[ep.number],
                ratio: ratio,
                watched: _isWatched(ratio),
                inProgress: _isInProgress(ratio),
                onTap: () => _playEpisode(ep, confirmIfResume: true),
                onToggleWatched: () => _toggleWatched(ep),
              );
            },
          ),
        ),
      ],
    );
  }

  FavoriteItem _favItem() => FavoriteItem(
        key: _favKey,
        name: widget.title,
        cover: widget.cover,
        mode: 'series',
        seriesId: widget.seriesId,
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.synopsis,
    required this.synopsisFromTmdb,
    required this.isLoadingTmdb,
    required this.tmdb,
    required this.providerRating,
    required this.seasonsCount,
    required this.cta,
    required this.isFav,
    required this.isWl,
    required this.onToggleFav,
    required this.onToggleWl,
    required this.onAddToCollection,
  });

  final String title;
  final String synopsis;
  final bool synopsisFromTmdb;
  final bool isLoadingTmdb;
  final TmdbResult? tmdb;
  final String? providerRating;
  final int seasonsCount;
  final ({String label, IconData icon, VoidCallback action})? cta;
  final bool isFav;
  final bool isWl;
  final VoidCallback onToggleFav;
  final VoidCallback onToggleWl;
  final VoidCallback onAddToCollection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ratingNumeric = formattedRating(tmdb?.rating);
    final ratingText = ratingNumeric.isNotEmpty
        ? ratingNumeric
        : ((providerRating ?? '').isNotEmpty && providerRating != '0'
            ? providerRating!
            : '');
    final year = tmdb?.year != null ? tmdb!.year.toString() : '';
    final hasMeta = ratingText.isNotEmpty || year.isNotEmpty || seasonsCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DSText.displayHero.copyWith(
            color: Colors.white,
            shadows: const <Shadow>[
              Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
        ),
        SizedBox(height: DS.space.md),

        if (hasMeta)
          _MetadataStrip(
            ratingText: ratingText,
            year: year,
            seasonsCount: seasonsCount,
            seasonsLabel: l10n.saisons.toLowerCase(),
          ),

        if (synopsis.isNotEmpty) ...<Widget>[
          SizedBox(height: DS.space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ShaderMask(
              shaderCallback: (Rect bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.black, Colors.black, Colors.transparent],
                stops: <double>[0, 0.85, 1],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                synopsis,
                style: DSText.body.copyWith(color: DS.colour.textSecondary),
              ),
            ),
          ),
          if (synopsisFromTmdb) ...<Widget>[
            SizedBox(height: DS.space.xs),
            const TmdbBadge(),
          ],
        ] else if (isLoadingTmdb) ...<Widget>[
          SizedBox(height: DS.space.md),
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: DS.colour.textTertiary,
            ),
          ),
        ],

        SizedBox(height: DS.space.md),

        Wrap(
          spacing: DS.space.md,
          runSpacing: DS.space.sm,
          children: <Widget>[
            if (cta != null)
              PrimaryHeroButton(
                label: cta!.label,
                icon: cta!.icon,
                onPressed: cta!.action,
                autofocus: true,
              ),
            GhostHeroButton(
              label: isFav ? l10n.retirer : l10n.favoris,
              icon: isFav ? Icons.favorite : Icons.favorite_border,
              activeTint: AppColors.accentWarm,
              isActive: isFav,
              onPressed: onToggleFav,
            ),
            GhostHeroButton(
              label: isWl ? l10n.retirer : l10n.aRegarder,
              icon: isWl ? Icons.bookmark : Icons.bookmark_border,
              activeTint: AppColors.primaryBlue,
              isActive: isWl,
              onPressed: onToggleWl,
            ),
            // Add-to-collection CTA — mirror of tvOS
            // `SeriesDetailView` secondary `Menu { ForEach
            // collections }`. Routes through the shared
            // `addToCollectionFlow` helper so the picker behaviour
            // (premium gate, create-if-empty, snackbar feedback)
            // stays in sync with VOD detail + home stream-tile.
            GhostHeroButton(
              label: l10n.ajouterCollection,
              icon: Icons.folder_outlined,
              onPressed: onAddToCollection,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({
    required this.ratingText,
    required this.year,
    required this.seasonsCount,
    required this.seasonsLabel,
  });

  final String ratingText;
  final String year;
  final int seasonsCount;
  final String seasonsLabel;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (ratingText.isNotEmpty) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.star, size: 16, color: AppColors.warning),
          SizedBox(width: DS.space.xxs),
          Text(
            ratingText,
            style: DSText.bodyEmphasised.copyWith(color: Colors.white),
          ),
        ],
      ));
    }
    if (year.isNotEmpty) {
      parts.add(Text(
        year,
        style: DSText.bodyEmphasised.copyWith(color: DS.colour.textSecondary),
      ));
    }
    if (seasonsCount > 0) {
      parts.add(Text(
        '$seasonsCount $seasonsLabel',
        style: DSText.bodyEmphasised.copyWith(color: DS.colour.textSecondary),
      ));
    }

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.space.sm),
          child: Text(
            '·',
            style: DSText.bodyEmphasised.copyWith(
              color: DS.colour.textTertiary,
            ),
          ),
        ));
      }
      children.add(parts[i]);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selectedSeason,
    required this.watchedCounter,
    required this.totalCounter,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<String> seasons;
  final String? selectedSeason;
  final int Function(String) watchedCounter;
  final int Function(String) totalCounter;
  final ValueChanged<String> onSelect;

  /// Fired on right-click (desktop) or long-press (touch). Carries
  /// the global position so the receiver can pop a contextual menu
  /// near the chip — used to bulk-mark a season as watched / unwatched.
  final void Function(String season, Offset globalPosition) onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => SizedBox(width: DS.space.sm),
        itemBuilder: (_, i) {
          final s = seasons[i];
          final selected = s == selectedSeason;
          final watched = watchedCounter(s);
          final total = totalCounter(s);
          final isComplete = total > 0 && watched == total;
          return _SeasonChip(
            label: l10n.saison(s),
            selected: selected,
            isComplete: isComplete,
            watched: watched,
            total: total,
            onTap: () => onSelect(s),
            onLongPress: (pos) => onLongPress(s, pos),
          );
        },
      ),
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.isComplete,
    required this.watched,
    required this.total,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool selected;
  final bool isComplete;
  final int watched;
  final int total;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPress;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color fg;
    if (_hovered) {
      fill = Colors.white;
      fg = Colors.black;
    } else if (widget.selected) {
      fill = AppColors.primaryBlue;
      fg = Colors.white;
    } else {
      fill = Colors.white.withValues(alpha: 0.10);
      fg = widget.isComplete ? AppColors.success : DS.colour.textSecondary;
    }
    final scale = _hovered ? DS.focus.chipScale : 1.0;

    return Tooltip(
      message: AppLocalizations.of(context)!.clicDroitMarquerSaison,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (d) => widget.onLongPress(d.globalPosition),
        onLongPressStart: (d) => widget.onLongPress(d.globalPosition),
        child: AnimatedScale(
          scale: scale,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: AnimatedContainer(
            duration: DS.focus.animation,
            curve: DS.focus.curve,
            padding: EdgeInsets.symmetric(
              horizontal: DS.space.lg,
              vertical: DS.space.xs,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(DS.radius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.label,
                  style: DSText.bodyEmphasised.copyWith(color: fg),
                ),
                if (widget.isComplete) ...<Widget>[
                  SizedBox(width: DS.space.xxs),
                  Icon(Icons.check_circle, size: 16, color: fg),
                ] else if (widget.watched > 0) ...<Widget>[
                  SizedBox(width: DS.space.xxs),
                  Text(
                    '${widget.watched}/${widget.total}',
                    style: DSText.caption.copyWith(
                      color: fg.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    required this.episode,
    required this.season,
    required this.cover,
    required this.ratio,
    required this.watched,
    required this.inProgress,
    required this.onTap,
    required this.onToggleWatched,
    this.meta,
  });

  final Episode episode;
  final String season;
  final String cover;
  final double? ratio;
  final bool watched;
  final bool inProgress;
  final VoidCallback onTap;
  final Future<void> Function() onToggleWatched;

  /// Optional TMDB per-episode metadata. When present, the row swaps
  /// the series poster for the episode's 16:9 still and shows the
  /// TMDB-curated episode name + synopsis.
  final EpisodeMeta? meta;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _hovered = false;

  String get _epPrefix {
    final s = int.tryParse(widget.season) ?? 0;
    final e = widget.episode.number;
    return 'S${s.toString().padLeft(2, '0')}E${e.toString().padLeft(2, '0')}';
  }

  void _showContextMenu(Offset position) {
    final l10n = AppLocalizations.of(context)!;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: AppColors.darkSurface,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'toggle',
          // Same constraint as the season menu — single Text child to
          // dodge the ListTile / Row max-width clamp in M3.
          child: Text(
            widget.watched ? l10n.marquerNonVu : l10n.marquerVu,
            style: DSText.body.copyWith(color: Colors.white),
          ),
        ),
      ],
    ).then((v) {
      if (v == 'toggle') widget.onToggleWatched();
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.watched
        ? DS.colour.textTertiary
        : DS.colour.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (d) => _showContextMenu(d.globalPosition),
        onLongPressStart: (d) => _showContextMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(DS.radius.card),
          ),
          padding: EdgeInsets.all(DS.space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(
                cover: widget.meta?.stillUrl(size: 'w300') ?? widget.cover,
                hovered: _hovered,
              ),
              SizedBox(width: DS.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          _epPrefix,
                          style: DSText.label.copyWith(
                            color: AppColors.primaryBlueLighter,
                          ),
                        ),
                        SizedBox(width: DS.space.xs),
                        Expanded(
                          child: Text(
                            // Prefer TMDB-curated episode name ("Pilot",
                            // "Vertigo") over the provider's
                            // `displayTitle`, which often duplicates
                            // the series title + episode number.
                            widget.meta?.name.isNotEmpty == true
                                ? widget.meta!.name
                                : widget.episode.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DSText.title3.copyWith(color: titleColor),
                          ),
                        ),
                      ],
                    ),
                    if (widget.meta?.overview.isNotEmpty == true) ...<Widget>[
                      SizedBox(height: DS.space.xxs),
                      Text(
                        widget.meta!.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DSText.body.copyWith(
                          color: DS.colour.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (widget.inProgress && widget.ratio != null) ...<Widget>[
                      SizedBox(height: DS.space.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(DS.radius.tag),
                          child: LinearProgressIndicator(
                            value: widget.ratio,
                            minHeight: 4,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: DS.space.sm),
              Icon(
                widget.watched ? Icons.check_circle : Icons.play_circle_fill,
                size: 28,
                color: widget.watched
                    ? AppColors.success
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.cover, required this.hovered});

  final String cover;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final size = const Size(200, 112);
    final placeholder = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(DS.radius.card),
      ),
      child: Icon(Icons.tv, size: 28, color: DS.colour.textTertiary),
    );

    final body = cover.isNotEmpty
        ? CachedNetworkImage(
            cacheManager: AppCacheManager.instance,
            imageUrl: cover,
            width: size.width,
            height: size.height,
            fit: BoxFit.cover,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          )
        : placeholder;

    return AnimatedScale(
      scale: hovered ? 1.04 : 1.0,
      duration: DS.focus.animation,
      curve: DS.focus.curve,
      child: AnimatedContainer(
        duration: DS.focus.animation,
        curve: DS.focus.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DS.radius.card),
          boxShadow: hovered
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DS.radius.card),
          child: body,
        ),
      ),
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.cast});

  final List<TmdbCast> cast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppLocalizations.of(context)!.distribution,
                style: DSText.title2.copyWith(color: Colors.white),
              ),
              SizedBox(width: DS.space.sm),
              const TmdbBadge(),
            ],
          ),
        ),
        SizedBox(height: DS.space.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
          child: TmdbCastRow(cast: cast),
        ),
      ],
    );
  }
}
