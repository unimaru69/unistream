import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/favorite_item.dart';
import '../../models/vod_item.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/watch_progress_provider.dart';
import '../../providers/tmdb_provider.dart';
import '../../repositories/content_repository.dart';
import '../../services/tmdb_service.dart';
import '../../utils/content_key.dart';
import '../../utils/routes.dart';
import '../../widgets/plex_backdrop.dart';
import '../../widgets/tmdb_cast_row.dart';
import '../../widgets/tmdb_badge.dart';
import '../../widgets/tmdb_trailer_button.dart';
import '../player/player_screen.dart';

/// Full-page detail screen for a VOD item.
/// Shows poster, title, rating, synopsis, play/resume, favorite/watchlist.
class VodDetailScreen extends ConsumerStatefulWidget {
  final VodItem vod;
  const VodDetailScreen({super.key, required this.vod});

  @override
  ConsumerState<VodDetailScreen> createState() => _VodDetailScreenState();
}

class _VodDetailScreenState extends ConsumerState<VodDetailScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  VodItem get vod => widget.vod;
  // Bare id for the favourite — aligns with tvOS's
  // `FavoriteItem.from(vod:)` (key = streamId, no prefix).
  String get _favKey => vod.id.toString();
  // Underscore-prefixed id for watch progress / history — same format
  // tvOS pushes to `user_watch_progress.content_key`.
  String get _wpKey => ContentKey.make(ContentKey.movie, vod.id.toString());

  Duration? _savedPosition;
  Duration? _savedDuration;

  /// A film is considered watched once it's past the 95% mark.
  bool get _isWatched {
    final pos = _savedPosition, dur = _savedDuration;
    if (pos == null || dur == null || dur.inSeconds <= 0) return false;
    return pos.inSeconds / dur.inSeconds > 0.95;
  }

  /// Mark the current film as watched (fake a near-end progress) or clear it.
  Future<void> _toggleWatched() async {
    if (_isWatched) {
      await _wp.clear(_wpKey);
    } else {
      // Order matters: `saveMeta` must run *before* `save` so the
      // upcoming Supabase push carries the title. Otherwise the row
      // briefly hits Supabase with `meta_json: "{}"` and any other
      // device that pulls in that window shows the raw content key.
      const dur = Duration(hours: 1);
      const pos = Duration(minutes: 57);
      await _wp.saveMeta(_wpKey, vod.name, vod.displayIcon, '', 'vod');
      await _wp.save(_wpKey, pos, dur);
    }
    await _loadProgress();
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  WatchProgressActions get _wp => ref.read(watchProgressActionsProvider);

  Future<void> _loadProgress() async {
    final progress = await _wp.getProgress(_wpKey);
    if (mounted) setState(() { _savedPosition = progress.position; _savedDuration = progress.duration; });
  }

  void _play({bool resume = false}) {
    final ext = vod.containerExtension;
    final url = _repo.getVodStreamUrl(vod.id, ext);
    final title = vod.name.isEmpty ? AppLocalizations.of(context)!.sansTitre : vod.name;
    _wp.saveMeta(_wpKey, title, vod.displayIcon, url, 'vod');
    _wp.saveHistory(_wpKey, title, vod.displayIcon, url, 'vod');
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: title,
      resumeKey: resume ? _wpKey : null,
      coverUrl: vod.displayIcon.isNotEmpty ? vod.displayIcon : null,
    ))).then((_) => _loadProgress());
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final favState = ref.watch(favoritesProvider);
    final wlState = ref.watch(watchlistProvider);
    final isFav = favState.keys.contains(_favKey);
    final isWl = wlState.keys.contains(_favKey);
    final title = vod.name.isEmpty ? l10n.sansTitre : vod.name;

    final hasResume = _savedPosition != null && _savedPosition!.inSeconds > 30;
    double? progressRatio;
    if (_savedPosition != null && _savedDuration != null && _savedDuration!.inSeconds > 0) {
      progressRatio = (_savedPosition!.inSeconds / _savedDuration!.inSeconds).clamp(0.0, 1.0);
    }

    final sourceSynopsis = vod.plot ?? vod.description ?? '';
    final needsEnrichment = sourceSynopsis.trim().isEmpty;
    final tmdbCfg = ref.watch(tmdbConfigProvider);
    final tmdbAsync = (tmdbCfg.isActive)
        ? ref.watch(tmdbLookupProvider(TmdbLookup(
            rawTitle: vod.name,
            kind: TmdbKind.movie,
          )))
        : const AsyncValue<TmdbResult?>.data(null);
    final tmdb = tmdbAsync.valueOrNull;
    final effectiveSynopsis =
        needsEnrichment ? (tmdb?.overview ?? '') : sourceSynopsis;
    // "original" keeps the image sharp on wide desktop windows (the hero /
    // backdrop scales ×1.2 internally so we want the highest-res source).
    // While TMDB is still loading we DON'T fall back to the low-res IPTV
    // poster — the split-second swap from a blurry poster to a sharp
    // cinematic backdrop is jarring. Show a plain dark background instead
    // and let the real image fade in once TMDB settles.
    final tmdbBackdrop = TmdbService.image(tmdb?.backdropPath, size: 'original');
    final String backdropUrl;
    if (tmdbBackdrop != null) {
      backdropUrl = tmdbBackdrop;
    } else if (tmdbAsync.isLoading) {
      backdropUrl = ''; // neutral dark fill, no flash
    } else {
      backdropUrl = vod.displayIcon;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Plex-style blurred backdrop — prefer the wide TMDB backdrop when
          // available (cinematic 16:9), fall back to the source poster.
          PlexBackdrop(imageUrl: backdropUrl),
          CustomScrollView(
        slivers: [
          // Poster as SliverAppBar — sits on top of the backdrop so the user
          // still sees the sharp cover at the top of the scroll.
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: backdropUrl.isNotEmpty
                  ? Stack(children: [
                      Positioned.fill(
                        // Prefer the TMDB wide backdrop (up to 1920×1080) over
                        // the low-res IPTV poster that got pixelated when
                        // stretched across the hero.
                        child: CachedNetworkImage(
                          cacheManager: AppCacheManager.instance,
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.transparent,
                            child: Icon(Icons.movie, size: 64, color: tc.borderColor),
                          ),
                        ),
                      ),
                      // Soft fade into the backdrop at the bottom of the hero.
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.darkBackground.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ])
                  : Container(
                      color: Colors.transparent,
                      child: Icon(Icons.movie, size: 64, color: tc.borderColor),
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — always white because the Plex backdrop behind is
                  // always dark (regardless of light/dark theme).
                  Text(title, style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  )),
                  const SizedBox(height: 8),

                  // Metadata row: rating, category, extension — white-ish
                  // against the dark plex backdrop.
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (vod.rating != null && vod.rating!.isNotEmpty && vod.rating != '0')
                        _MetadataChip(icon: Icons.star, label: vod.rating!, color: Colors.amber),
                      if (vod.categoryName != null && vod.categoryName!.isNotEmpty)
                        _MetadataChip(
                          icon: Icons.category,
                          label: vod.categoryName!,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      _MetadataChip(
                        icon: Icons.high_quality,
                        label: vod.containerExtension.toUpperCase(),
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(children: [
                    // Play button
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.lire),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => _play(resume: false),
                    ),
                    if (hasResume) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.replay),
                        label: Text(l10n.reprendre(_fmtDuration(_savedPosition!))),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () => _play(resume: true),
                      ),
                    ],
                    const SizedBox(width: 12),
                    // Favorite toggle
                    IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : tc.textSecondary),
                      tooltip: l10n.favoris,
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggle(_favKey, FavoriteItem(
                          key: _favKey, name: vod.name, cover: vod.displayIcon,
                          mode: 'vod', streamId: vod.id,
                          categoryId: vod.categoryId, containerExtension: vod.containerExtension,
                          streamIcon: vod.streamIcon,
                        ));
                      },
                    ),
                    // Watchlist toggle
                    IconButton(
                      icon: Icon(isWl ? Icons.bookmark : Icons.bookmark_border,
                          color: isWl ? AppColors.primaryBlue : tc.textSecondary),
                      tooltip: l10n.aRegarder,
                      onPressed: () {
                        ref.read(watchlistProvider.notifier).toggle(_favKey, FavoriteItem(
                          key: _favKey, name: vod.name, cover: vod.displayIcon,
                          mode: 'vod', streamId: vod.id,
                          categoryId: vod.categoryId, containerExtension: vod.containerExtension,
                          streamIcon: vod.streamIcon,
                        ));
                      },
                    ),
                    // Mark as watched / unwatched — parity with Series detail.
                    IconButton(
                      icon: Icon(
                        _isWatched ? Icons.visibility_off : Icons.check_circle_outline,
                        color: _isWatched ? Colors.green : tc.textSecondary,
                      ),
                      tooltip: _isWatched ? l10n.marquerNonVu : l10n.marquerVu,
                      onPressed: _toggleWatched,
                    ),
                  ]),

                  // "Déjà vu" badge when the film has been watched.
                  if (_isWatched) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l10n.marquerVu.startsWith('Marquer')
                              ? 'Déjà vu'
                              : l10n.marquerVu,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Progress bar
                  if (progressRatio != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        backgroundColor: tc.divider,
                        color: AppColors.primaryBlue,
                        minHeight: 4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Synopsis — white on dark backdrop. Falls back to TMDB
                  // when the source has none.
                  Row(children: [
                    Text(l10n.detailVod,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                    if (needsEnrichment && effectiveSynopsis.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const TmdbBadge(),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  if (tmdbAsync.isLoading && sourceSynopsis.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  else
                    Text(
                      effectiveSynopsis.isNotEmpty
                          ? effectiveSynopsis
                          : l10n.pasDeSynopsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: effectiveSynopsis.isNotEmpty
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.45),
                        height: 1.5,
                      ),
                    ),

                  // Trailer + cast — only when TMDB delivered results.
                  if (tmdb != null && tmdb.videos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TmdbTrailerButton(videos: tmdb.videos),
                  ],
                  if (tmdb != null && tmdb.cast.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      const Text('Distribution',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                      const SizedBox(width: 8),
                      const TmdbBadge(),
                    ]),
                    const SizedBox(height: 8),
                    TmdbCastRow(cast: tmdb.cast),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 13, color: color)),
    ]);
  }
}
