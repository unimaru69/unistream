import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/colors.dart';
import '../../core/design_tokens.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/favorite_item.dart';
import '../../models/vod_item.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/tmdb_provider.dart';
import '../../providers/watch_progress_provider.dart';
import '../../repositories/content_repository.dart';
import '../../services/tmdb_service.dart';
import '../../utils/content_key.dart';
import '../../utils/routes.dart';
import '../../utils/title_formatting.dart';
import '../../widgets/hero_buttons.dart';
import '../../widgets/plex_backdrop.dart';
import '../../widgets/tmdb_badge.dart';
import '../../widgets/tmdb_cast_row.dart';
import '../../widgets/tmdb_trailer_button.dart';
import '../player/player_screen.dart';

/// Apple-TV+-style VOD detail. Full-bleed sharp backdrop, hero block
/// pushed to ~40 % of the viewport, displayHero title, metadata strip
/// (rating · year · runtime), synopsis with bottom-fade mask, primary
/// CTA + ghost CTAs (favori / à regarder / marquer vu), cast row.
///
/// Mirror of `tvos/UniStreamTV/UniStreamTV/Views/VOD/VODDetailView.swift`.
/// State management (Riverpod, watch progress, favourites, watchlist)
/// is unchanged from the previous implementation — only the visual
/// shell was refactored.
class VodDetailScreen extends ConsumerStatefulWidget {
  const VodDetailScreen({super.key, required this.vod});

  final VodItem vod;

  @override
  ConsumerState<VodDetailScreen> createState() => _VodDetailScreenState();
}

class _VodDetailScreenState extends ConsumerState<VodDetailScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  WatchProgressActions get _wp => ref.read(watchProgressActionsProvider);

  VodItem get vod => widget.vod;

  /// Bare id for the favourite — aligns with tvOS's
  /// `FavoriteItem.from(vod:)` (key = streamId, no prefix).
  String get _favKey => vod.id.toString();

  /// Underscore-prefixed id for watch progress / history — same format
  /// tvOS pushes to `user_watch_progress.content_key`.
  String get _wpKey => ContentKey.make(ContentKey.movie, vod.id.toString());

  Duration? _savedPosition;
  Duration? _savedDuration;

  /// A film is considered watched once it's at or past the 95 % mark.
  /// `>=` (not `>`) so the manual "Marquer vu" marker — which stores
  /// ratio = 0.95 exactly (57 min / 60 min, the largest value
  /// `WatchProgress.save` keeps without auto-clearing) — counts as
  /// watched. Without this the badge never appeared and the primary
  /// CTA stayed stuck on "Reprendre".
  bool get _isWatched {
    final pos = _savedPosition;
    final dur = _savedDuration;
    if (pos == null || dur == null || dur.inSeconds <= 0) return false;
    return pos.inSeconds / dur.inSeconds >= 0.95;
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await _wp.getProgress(_wpKey);
    if (!mounted) return;
    setState(() {
      _savedPosition = progress.position;
      _savedDuration = progress.duration;
    });
  }

  /// Mark the current film as watched (fake a near-end progress) or clear it.
  /// Uses the real saved duration when known so the stored entry
  /// reflects "I've seen the actual ~2 h film" instead of pretending
  /// the film is 1 h long. `WatchProgress.save` clears entries with
  /// ratio > 0.95, so we target exactly 0.95 (largest value that
  /// survives the auto-clean), and floor to integer seconds.
  Future<void> _toggleWatched() async {
    if (_isWatched) {
      await _wp.clear(_wpKey);
    } else {
      // Prefer the real duration if we already have one — keeps the
      // stored entry honest.
      final dur = (_savedDuration != null && _savedDuration!.inSeconds >= 60)
          ? _savedDuration!
          : const Duration(hours: 1);
      final pos = Duration(seconds: (dur.inSeconds * 0.95).floor());
      // saveMeta must run before save so the Supabase push carries the title.
      await _wp.saveMeta(_wpKey, vod.name, vod.displayIcon, '', 'vod');
      await _wp.save(_wpKey, pos, dur);
    }
    await _loadProgress();
  }

  /// Open the player. `resumeKey` is **always** passed so the player
  /// saves progress as you watch — without that, exiting the film
  /// loses everything (PlayerScreen only persists when `resumeKey`
  /// is non-null, see player_screen.dart:415/606/722).
  ///
  /// `restart: true` clears any existing progress first so "Revoir"
  /// (after the film was marked watched) starts from 0 instead of
  /// resuming at the 95 %+ position the saved entry holds.
  Future<void> _play({bool restart = false}) async {
    if (restart) {
      await _wp.clear(_wpKey);
      if (!mounted) return;
    }
    final l10n = AppLocalizations.of(context)!;
    final ext = vod.containerExtension;
    final url = _repo.getVodStreamUrl(vod.id, ext);
    final title = vod.name.isEmpty ? l10n.sansTitre : vod.name;
    _wp.saveMeta(_wpKey, title, vod.displayIcon, url, 'vod');
    _wp.saveHistory(_wpKey, title, vod.displayIcon, url, 'vod');
    if (!mounted) return;
    Navigator.push(
      context,
      slideRoute(PlayerScreen(
        url: url,
        title: title,
        resumeKey: _wpKey,
        coverUrl: vod.displayIcon.isNotEmpty ? vod.displayIcon : null,
      )),
    ).then((_) {
      // Defer by one frame — `.then` fires while the player route's
      // `_ModalScope` is still being torn down, and `_loadProgress`
      // does setState. Synchronous setState here triggers a rebuild
      // of this vod_detail subtree mid-cleanup, racing Flutter's
      // GlobalKey reconciliation (framework.dart:2168
      // `_InactiveElements.remove → _elements.contains`).
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProgress();
      });
    });
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  FavoriteItem _favItem() => FavoriteItem(
        key: _favKey,
        name: vod.name,
        cover: vod.displayIcon,
        mode: 'vod',
        streamId: vod.id,
        categoryId: vod.categoryId,
        containerExtension: vod.containerExtension,
        streamIcon: vod.streamIcon,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final favState = ref.watch(favoritesProvider);
    final wlState = ref.watch(watchlistProvider);
    final isFav = favState.keys.contains(_favKey);
    final isWl = wlState.keys.contains(_favKey);

    final hasResume =
        _savedPosition != null && _savedPosition!.inSeconds > 30;

    final sourceSynopsis = vod.plot ?? vod.description ?? '';
    final needsEnrichment = sourceSynopsis.trim().isEmpty;
    final tmdbCfg = ref.watch(tmdbConfigProvider);
    final tmdbAsync = tmdbCfg.isActive
        ? ref.watch(tmdbLookupProvider(TmdbLookup(
            rawTitle: vod.name,
            kind: TmdbKind.movie,
          )))
        : const AsyncValue<TmdbResult?>.data(null);
    final tmdb = tmdbAsync.valueOrNull;
    final effectiveSynopsis =
        needsEnrichment ? (tmdb?.overview ?? '') : sourceSynopsis;
    // While TMDB resolves, show neutral dark — avoids flashing the
    // low-res IPTV poster before the cinematic backdrop loads.
    final tmdbBackdrop = TmdbService.image(tmdb?.backdropPath, size: 'original');
    final String backdropUrl;
    if (tmdbBackdrop != null) {
      backdropUrl = tmdbBackdrop;
    } else if (tmdbAsync.isLoading) {
      backdropUrl = '';
    } else {
      backdropUrl = vod.displayIcon;
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    // Push the hero ~40 % down so the backdrop reads as cinematic
    // before the title block enters the page. Floor at 140 px on
    // small viewports (mobile portrait) so it doesn't get cramped.
    final heroOffset = (viewportHeight * 0.38).clamp(140.0, 420.0);

    final cleanedTitle = vod.name.cleanedTitleNoYear;
    final fallbackTitle = cleanedTitle.isEmpty ? l10n.sansTitre : cleanedTitle;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      // Transparent app bar — backdrop bleeds behind. Only purpose is
      // to host the back button (system back arrow on iOS / macOS).
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
          // Sharp backdrop — blurSigma=0. PlexBackdrop's gradients
          // (left-darken + bottom-fade + brand wash) keep the title
          // legible without softening the image itself.
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
                      synopsis: effectiveSynopsis,
                      synopsisFromTmdb: needsEnrichment &&
                          effectiveSynopsis.isNotEmpty,
                      tmdb: tmdb,
                      isLoadingTmdb: tmdbAsync.isLoading,
                      isWatched: _isWatched,
                      savedPosition: _savedPosition,
                      savedDuration: _savedDuration,
                      hasResume: hasResume,
                      isFav: isFav,
                      isWl: isWl,
                      onPlay: () => _play(restart: _isWatched),
                      onToggleFav: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(_favKey, _favItem()),
                      onToggleWl: () => ref
                          .read(watchlistProvider.notifier)
                          .toggle(_favKey, _favItem()),
                      onToggleWatched: _toggleWatched,
                      formatPosition: _fmtDuration,
                      providerRating: vod.rating,
                    ),
                  ),
                ),
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
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.synopsis,
    required this.synopsisFromTmdb,
    required this.tmdb,
    required this.isLoadingTmdb,
    required this.isWatched,
    required this.savedPosition,
    required this.savedDuration,
    required this.hasResume,
    required this.isFav,
    required this.isWl,
    required this.onPlay,
    required this.onToggleFav,
    required this.onToggleWl,
    required this.onToggleWatched,
    required this.formatPosition,
    required this.providerRating,
  });

  final String title;
  final String synopsis;
  final bool synopsisFromTmdb;
  final TmdbResult? tmdb;
  final bool isLoadingTmdb;
  final bool isWatched;
  final Duration? savedPosition;
  final Duration? savedDuration;
  final bool hasResume;
  final bool isFav;
  final bool isWl;
  final VoidCallback onPlay;
  final VoidCallback onToggleFav;
  final VoidCallback onToggleWl;
  final VoidCallback onToggleWatched;
  final String Function(Duration) formatPosition;
  final String? providerRating;

  /// Primary CTA copy reflects the user's progress.
  String _primaryCopy(AppLocalizations l10n) {
    if (isWatched) return l10n.revoir;
    if (hasResume && savedPosition != null) {
      return l10n.reprendre(formatPosition(savedPosition!));
    }
    return l10n.lire;
  }

  String _displayYear(String rawTitle) {
    if (tmdb?.year != null) return tmdb!.year.toString();
    return _parseTrailingYear(rawTitle) ?? '';
  }

  static String? _parseTrailingYear(String title) {
    final trimmed = title.trim();
    if (trimmed.length < 6 || !trimmed.endsWith(')')) return null;
    final open = trimmed.length - 6;
    if (trimmed[open] != '(') return null;
    final year = trimmed.substring(open + 1, trimmed.length - 1);
    if (year.length != 4) return null;
    final n = int.tryParse(year);
    if (n == null) return null;
    return year;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ratingNumeric = formattedRating(tmdb?.rating);
    final ratingText = ratingNumeric.isNotEmpty
        ? ratingNumeric
        : ((providerRating ?? '').isNotEmpty && providerRating != '0'
            ? providerRating!
            : '');
    final year = _displayYear(title);
    final runtime = formattedRuntime(tmdb?.runtime);
    final hasMeta =
        ratingText.isNotEmpty || year.isNotEmpty || runtime.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title — displayHero, drop shadow for legibility over the backdrop.
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

        // Metadata strip — rating · year · runtime.
        if (hasMeta) _MetadataStrip(
          ratingText: ratingText,
          year: year,
          runtime: runtime,
        ),

        if (synopsis.isNotEmpty) ...<Widget>[
          SizedBox(height: DS.space.md),
          // Capped-height synopsis with a bottom-fade mask. Long
          // blurbs read as cinematic rather than wall-of-text.
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
                style: DSText.body.copyWith(
                  color: DS.colour.textSecondary,
                ),
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

        // Resume / watched indicator — sits above the CTA row so the
        // user reads "Reprendre à 1:34:22" before pressing.
        if (isWatched)
          const _WatchedBadge()
        else if (hasResume && savedPosition != null && savedDuration != null)
          _ResumeProgress(
            position: savedPosition!,
            duration: savedDuration!,
            label: l10n.reprendreDepuis(formatPosition(savedPosition!)),
          ),

        SizedBox(height: DS.space.md),

        // Primary CTAs — Lire/Reprendre/Revoir + favori + à regarder.
        Wrap(
          spacing: DS.space.md,
          runSpacing: DS.space.sm,
          children: <Widget>[
            PrimaryHeroButton(
              label: _primaryCopy(l10n),
              icon: isWatched ? Icons.replay : Icons.play_arrow,
              onPressed: onPlay,
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
          ],
        ),

        SizedBox(height: DS.space.sm),

        // Secondary CTA — marquer vu / non vu.
        Wrap(
          spacing: DS.space.md,
          runSpacing: DS.space.sm,
          children: <Widget>[
            GhostHeroButton(
              label: isWatched ? l10n.marquerNonVu : l10n.marquerVu,
              icon: isWatched ? Icons.cancel_outlined : Icons.check_circle_outline,
              onPressed: onToggleWatched,
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
    required this.runtime,
  });

  final String ratingText;
  final String year;
  final String runtime;

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
    if (runtime.isNotEmpty) {
      parts.add(Text(
        runtime,
        style: DSText.bodyEmphasised.copyWith(color: DS.colour.textSecondary),
      ));
    }

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.space.sm),
          child: Text('·',
              style: DSText.bodyEmphasised.copyWith(
                color: DS.colour.textTertiary,
              )),
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

class _WatchedBadge extends StatelessWidget {
  const _WatchedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_circle, size: 18, color: AppColors.success),
        SizedBox(width: DS.space.xs),
        Text(
          AppLocalizations.of(context)!.dejaVu,
          style: DSText.bodyEmphasised.copyWith(color: AppColors.success),
        ),
      ],
    );
  }
}

class _ResumeProgress extends StatelessWidget {
  const _ResumeProgress({
    required this.position,
    required this.duration,
    required this.label,
  });

  final Duration position;
  final Duration duration;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ratio = duration.inSeconds > 0
        ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(DS.radius.tag),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryBlue,
              ),
            ),
          ),
          SizedBox(height: DS.space.xs),
          Text(
            label,
            style: DSText.caption.copyWith(color: DS.colour.textTertiary),
          ),
        ],
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
