import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../models/content_mode.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import '../providers/tmdb_provider.dart';
import '../services/tmdb_service.dart';
import '../utils/stream_helpers.dart';

/// Rotating "À la une" banner for the Home screen.
///
/// Fed with the same [items] list as [RecentlyAddedRow] (a mix of [VodItem]
/// and [SeriesItem]); picks the most promising ones and cycles between them
/// every [rotationInterval]. Parity with the Swift `HomeHeroBanner` on tvOS.
class HomeHeroBanner extends StatefulWidget {
  final List<dynamic> items;
  final ContentMode mode;
  final void Function(dynamic item) onTap;
  final Duration rotationInterval;

  /// Extra padding baked INSIDE the hero's top so the content clears the
  /// translucent app bar (`extendBodyBehindAppBar = true`). The blurred
  /// backdrop paints beneath the full height so it runs edge-to-edge under
  /// the app bar — no grey band.
  final double topInset;

  const HomeHeroBanner({
    super.key,
    required this.items,
    required this.mode,
    required this.onTap,
    this.rotationInterval = const Duration(seconds: 8),
    this.topInset = 0,
  });

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  // Content area (poster + text) — not counting the top inset reserved for
  // the translucent app bar. Total banner height = _bannerHeight + topInset.
  static const double _bannerHeight = 320;

  Timer? _timer;
  int _index = 0;
  late List<dynamic> _featured;

  @override
  void initState() {
    super.initState();
    _featured = _pickFeatured(widget.items);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeHeroBanner old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _featured = _pickFeatured(widget.items);
      _index = _featured.isEmpty ? 0 : _index % _featured.length;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_featured.length < 2) return;
    _timer = Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted || _featured.isEmpty) return;
      setState(() => _index = (_index + 1) % _featured.length);
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  /// Take up to 10 items that have a poster + rating + plot — interleaving
  /// films and series so the carousel alternates.
  List<dynamic> _pickFeatured(List<dynamic> all) {
    double scoreOf(dynamic it) {
      final r = double.tryParse(
            (it is VodItem ? it.rating : it is SeriesItem ? it.rating : null) ?? '',
          ) ??
          0;
      final hasPoster = getStreamIcon(it).isNotEmpty ? 1.0 : 0.0;
      final plot = it is VodItem ? (it.plot ?? it.description) : it is SeriesItem ? (it.plot) : null;
      final hasPlot = (plot != null && plot.isNotEmpty) ? 1.0 : 0.0;
      return r + hasPoster * 3 + hasPlot * 2;
    }

    final vods = all.whereType<VodItem>().toList()..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    final series = all.whereType<SeriesItem>().toList()..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    final topV = vods.take(5).toList();
    final topS = series.take(5).toList();

    final out = <dynamic>[];
    for (var i = 0; i < 5; i++) {
      if (i < topV.length) out.add(topV[i]);
      if (i < topS.length) out.add(topS[i]);
    }
    return out;
  }

  String _plotOf(dynamic item) {
    if (item is VodItem) return item.plot ?? item.description ?? '';
    if (item is SeriesItem) return item.plot ?? '';
    return '';
  }

  String? _ratingOf(dynamic item) {
    if (item is VodItem) return item.rating;
    if (item is SeriesItem) return item.rating;
    return null;
  }

  String _labelOf(dynamic item) =>
      item is VodItem ? 'FILM' : item is SeriesItem ? 'SÉRIE' : '';

  @override
  Widget build(BuildContext context) {
    if (_featured.isEmpty) return const SizedBox.shrink();
    final item = _featured[_index];
    final cover = getStreamIcon(item);
    final title = getStreamName(item);
    final plot = _plotOf(item);
    final rating = _ratingOf(item);
    final label = _labelOf(item);

    // ClipRect so the blurred backdrop (Transform.scale 1.2) can't bleed
    // into the rows below (Continue Watching, Recently Added).
    return ClipRect(child: SizedBox(
      height: _bannerHeight + widget.topInset,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: _HeroSlide(
          key: ValueKey('${_index}_$title'),
          cover: cover,
          title: title,
          plot: plot,
          rating: rating,
          label: label,
          pageCount: _featured.length,
          currentPage: _index,
          topInset: widget.topInset,
          onTap: () => widget.onTap(item),
          kind: item is VodItem ? TmdbKind.movie : TmdbKind.tv,
        ),
      ),
    ));
  }
}

class _HeroSlide extends ConsumerWidget {
  final String cover;
  final String title;
  final String plot;
  final String? rating;
  final String label;
  final int pageCount;
  final int currentPage;
  final double topInset;
  final VoidCallback onTap;
  final TmdbKind kind;

  const _HeroSlide({
    super.key,
    required this.cover,
    required this.title,
    required this.plot,
    required this.rating,
    required this.label,
    required this.pageCount,
    required this.currentPage,
    required this.topInset,
    required this.onTap,
    required this.kind,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the TMDB wide backdrop when available — it's designed for this
    // layout (vs the source poster which is 2:3 and looks squashed).
    final cfg = ref.watch(tmdbConfigProvider);
    final tmdb = cfg.isActive
        ? ref
            .watch(tmdbLookupProvider(
                TmdbLookup(rawTitle: title, kind: kind)))
            .valueOrNull
        : null;
    // Use the original-resolution backdrop for the hero because it covers
    // the full window width on desktops and we scale it ×1.2 on top of that
    // (blur). w1280 looked pixelated on >1500px windows.
    final backdropUrl =
        TmdbService.image(tmdb?.backdropPath, size: 'original') ?? cover;
    return _buildSlide(context, backdropUrl, tmdb?.overview ?? plot);
  }

  Widget _buildSlide(BuildContext context, String backdropUrl, String effectivePlot) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark base so the hero never shows white while loading.
        ColoredBox(color: AppColors.darkBackground),
        // Blurred backdrop of the poster — softer blur + fuller opacity so
        // the image actually shows through (previously invisible at sigma 22).
        if (backdropUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Transform.scale(
              scale: 1.2,
              child: CachedNetworkImage(
                cacheManager: AppCacheManager.instance,
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        // Left→right darken — keep the left (text) legible but let the right
        // side breathe so the image is visibly present.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.darkBackground.withValues(alpha: 0.78),
                AppColors.darkBackground.withValues(alpha: 0.40),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Brand accent wash from the top-left.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, -0.9),
              radius: 1.0,
              colors: [
                AppColors.primaryBlue.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Bottom vignette so the hero fades into the next section.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.darkBackground.withValues(alpha: 0.75)],
            ),
          ),
        ),
        // Foreground content — pushed down by the app-bar height so it
        // clears the translucent bar above. The backdrop itself fills all
        // the way to the top of the window.
        Padding(
          padding: EdgeInsets.fromLTRB(28, topInset + 16, 28, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sharp poster on the left — tall, cinematic.
              if (cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radius.hero),
                  child: CachedNetworkImage(
                    cacheManager: AppCacheManager.instance,
                    imageUrl: cover,
                    width: 170,
                    height: 255,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 170,
                      height: 255,
                      color: AppColors.darkSurface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 170,
                      height: 255,
                      color: AppColors.darkSurface,
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
                  ),
                ),
              const SizedBox(width: 28),
              // Text + CTA.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ribbon + label.
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'À LA UNE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                    if (rating != null && rating!.isNotEmpty && rating != '0') ...[
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(rating!,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      ]),
                    ],
                    if (effectivePlot.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        effectivePlot,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 14,
                          height: 1.4,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Compact CTA pill.
                    FilledButton.icon(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Regarder',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Page dots.
        if (pageCount > 1)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (i) {
                final active = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 3,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
