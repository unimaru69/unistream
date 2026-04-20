import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../models/content_mode.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
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

  const HomeHeroBanner({
    super.key,
    required this.items,
    required this.mode,
    required this.onTap,
    this.rotationInterval = const Duration(seconds: 8),
  });

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  // Kept compact so the main grid breathes. If you want more cinematic feel
  // bump this to ~240 — but make sure the grid still shows >= 2 full rows.
  static const double _bannerHeight = 190;

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

    return SizedBox(
      height: _bannerHeight,
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
          onTap: () => widget.onTap(item),
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final String cover;
  final String title;
  final String plot;
  final String? rating;
  final String label;
  final int pageCount;
  final int currentPage;
  final VoidCallback onTap;

  const _HeroSlide({
    super.key,
    required this.cover,
    required this.title,
    required this.plot,
    required this.rating,
    required this.label,
    required this.pageCount,
    required this.currentPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred backdrop.
        ColoredBox(color: AppColors.darkBackground),
        if (cover.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Transform.scale(
              scale: 1.1,
              child: Opacity(
                opacity: 0.9,
                child: CachedNetworkImage(
                  cacheManager: AppCacheManager.instance,
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        // Leading darken gradient.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.darkBackground.withValues(alpha: 0.88),
                AppColors.darkBackground.withValues(alpha: 0.55),
                AppColors.darkBackground.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Bottom fade.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.darkBackground],
            ),
          ),
        ),
        // Foreground content.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sharp poster on the left — sized for the compact banner.
              if (cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radius.hero),
                  child: CachedNetworkImage(
                    cacheManager: AppCacheManager.instance,
                    imageUrl: cover,
                    width: 105,
                    height: 158,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 105,
                      height: 158,
                      color: AppColors.darkSurface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 105,
                      height: 158,
                      color: AppColors.darkSurface,
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
                  ),
                ),
              const SizedBox(width: 20),
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
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
                    if (plot.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        plot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
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
