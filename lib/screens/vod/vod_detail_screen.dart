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
import '../../repositories/content_repository.dart';
import '../../utils/routes.dart';
import '../../widgets/plex_backdrop.dart';
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
  String get _favKey => 'vod:${vod.id}';

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
      await _wp.clear(vod.id);
    } else {
      // Use a 1-hour duration as a reasonable default when we have no real
      // duration yet — mirrors the pattern used for series episodes.
      const dur = Duration(hours: 1);
      const pos = Duration(minutes: 57);
      await _wp.save(vod.id, pos, dur);
      await _wp.saveMeta(vod.id, vod.name, vod.displayIcon, '', 'vod');
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
    final progress = await _wp.getProgress(vod.id);
    if (mounted) setState(() { _savedPosition = progress.position; _savedDuration = progress.duration; });
  }

  void _play({bool resume = false}) {
    final ext = vod.containerExtension;
    final url = _repo.getVodStreamUrl(vod.id, ext);
    final title = vod.name.isEmpty ? AppLocalizations.of(context)!.sansTitre : vod.name;
    _wp.saveMeta(vod.id, title, vod.displayIcon, url, 'vod');
    _wp.saveHistory('vod:${vod.id}', title, vod.displayIcon, url, 'vod');
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: title,
      resumeKey: resume ? vod.id : null,
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

    final synopsis = vod.plot ?? vod.description ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Plex-style blurred backdrop of the poster.
          PlexBackdrop(imageUrl: vod.displayIcon),
          CustomScrollView(
        slivers: [
          // Poster as SliverAppBar — sits on top of the backdrop so the user
          // still sees the sharp cover at the top of the scroll.
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: vod.displayIcon.isNotEmpty
                  ? Stack(children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          cacheManager: AppCacheManager.instance,
                          imageUrl: vod.displayIcon,
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
                  // Title
                  Text(title, style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tc.textPrimary,
                  )),
                  const SizedBox(height: 8),

                  // Metadata row: rating, category, extension
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (vod.rating != null && vod.rating!.isNotEmpty && vod.rating != '0')
                        _MetadataChip(icon: Icons.star, label: vod.rating!, color: Colors.amber),
                      if (vod.categoryName != null && vod.categoryName!.isNotEmpty)
                        _MetadataChip(icon: Icons.category, label: vod.categoryName!, color: tc.textSecondary),
                      _MetadataChip(
                        icon: Icons.high_quality,
                        label: vod.containerExtension.toUpperCase(),
                        color: tc.textSecondary,
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

                  // Synopsis
                  Text(l10n.detailVod,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tc.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    synopsis.isNotEmpty ? synopsis : l10n.pasDeSynopsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: synopsis.isNotEmpty ? tc.textSecondary : tc.textDisabled,
                      height: 1.5,
                    ),
                  ),

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
