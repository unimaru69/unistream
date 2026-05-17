import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache_config.dart';
import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/series_item.dart';
import '../../../models/vod_item.dart';
import '../../../providers/tmdb_provider.dart';
import '../../../services/tmdb_service.dart';
import '../../../utils/stream_helpers.dart';
import '../../../utils/title_formatting.dart';
import '../../../widgets/hero_buttons.dart';

/// Apple-TV+-style Home hero. Mirror of
/// `tvos/UniStreamTV/UniStreamTV/Views/Home/HomeHeroBanner.swift`.
///
/// - Full-bleed TMDB backdrop with a gentle 8 px blur (cinematic, not
///   muddy) + bottom-up darken so the foreground reads
/// - Foreground sits in the lower-left third: "À la une" pill + badge
///   (FILM / SÉRIE) + displayHero title + rating + plot + CTA
/// - Page dots at the bottom (active = wide accent capsule)
/// - Auto-rotates every [rotationInterval]; calling [onCurrentItemChanged]
///   on every transition so a parent can sync a full-screen ambient
///   wallpaper behind the rest of the Accueil
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({
    super.key,
    required this.items,
    required this.topInset,
    required this.onPlayItem,
    this.onCurrentItemChanged,
    this.rotationInterval = const Duration(seconds: 8),
    this.transparentBackdrop = false,
  });

  final List<dynamic> items;
  final double topInset;
  final void Function(dynamic item) onPlayItem;
  final void Function(dynamic item)? onCurrentItemChanged;
  final Duration rotationInterval;

  /// When `true`, the hero skips rendering its own image backdrop and
  /// relies on the parent to paint a full-screen wallpaper behind the
  /// page (Apple-TV+-style continuous backdrop). On surfaces where the
  /// hero is the only backdrop source (Films / Séries split views),
  /// leave this `false` and the hero will draw its own image.
  final bool transparentBackdrop;

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  Timer? _timer;
  int _index = 0;
  late List<dynamic> _featured;
  // Trackpad two-finger horizontal swipe accumulator. macOS emits
  // `PointerPanZoom*` events for trackpad gestures which `GestureDetector`
  // does not surface as drags — we have to listen at the `Listener` layer
  // and integrate the pan delta ourselves. Reset on every pan-zoom-start.
  double _panZoomDx = 0;

  @override
  void initState() {
    super.initState();
    _featured = _pickFeatured(widget.items);
    // **No** initial emit from initState — the parent can read
    // `featured.first` itself as a wallpaper fallback. Emitting
    // synchronously (or via post-frame) from initState tripped the
    // framework's element-lifecycle assertion at startup
    // (`element._lifecycleState == _ElementLifecycle.active`) because
    // the parent's setState landed while ancestors were still
    // settling their first build.
    HardwareKeyboard.instance.addHandler(_onKey);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeHero old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _featured = _pickFeatured(widget.items);
      _index = _featured.isEmpty ? 0 : _index % _featured.length;
      // Skip the synchronous emit — see `initState` note. Timer-driven
      // emits are safe (run after mount is fully settled).
      _restartTimer();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.dispose();
  }

  /// Keyboard navigation for the hero carousel. Left / Right arrows step
  /// between featured items when the Accueil is the topmost route and no
  /// text field is currently editing. Returns true once we handle the
  /// event so a downstream handler (grid, sidebar) doesn't also react.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!mounted || _featured.length < 2) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    // Don't hijack arrow keys while the user is typing in a TextField
    // or any focusable text input.
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null && focused.context?.widget is EditableText) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return true;
    }
    return false;
  }

  void _startTimer() {
    if (_featured.length < 2) return;
    _timer = Timer.periodic(widget.rotationInterval, (_) {
      if (!mounted || _featured.isEmpty) return;
      setState(() => _index = (_index + 1) % _featured.length);
      _emitCurrent();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  void _emitCurrent() {
    final cb = widget.onCurrentItemChanged;
    if (cb == null) return;
    cb(_featured.isEmpty ? null : _featured[_index]);
  }

  /// Score + interleave VOD/Series candidates, matching the tvOS
  /// load() heuristic. Items without a poster are penalised so we
  /// don't open on a placeholder.
  List<dynamic> _pickFeatured(List<dynamic> all) {
    double score(dynamic it) {
      final r = double.tryParse(
            (it is VodItem
                    ? it.rating
                    : it is SeriesItem
                        ? it.rating
                        : null) ??
                '',
          ) ??
          0;
      final hasPoster = getStreamIcon(it).isNotEmpty ? 3.0 : -2.0;
      final plot = it is VodItem
          ? (it.plot ?? it.description)
          : it is SeriesItem
              ? it.plot
              : null;
      final hasPlot = (plot != null && plot.isNotEmpty) ? 2.0 : 0.0;
      return r + hasPoster + hasPlot;
    }

    final vods = all.whereType<VodItem>().toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    final series = all.whereType<SeriesItem>().toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    final topV = vods.take(5).toList();
    final topS = series.take(5).toList();

    final out = <dynamic>[];
    for (var i = 0; i < 5; i++) {
      if (i < topV.length) out.add(topV[i]);
      if (i < topS.length) out.add(topS[i]);
    }
    return out;
  }

  void _step(int delta) {
    if (_featured.length < 2) return;
    setState(() {
      _index = (_index + delta + _featured.length) % _featured.length;
    });
    _emitCurrent();
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_featured.isEmpty) {
      return SizedBox(
        height: widget.topInset + 320,
        child: const _Placeholder(),
      );
    }
    // Responsive hero height: 56 % of viewport, clamped 480..720 so it
    // stays cinematic on big monitors but doesn't trap the user on
    // small windows.
    final vh = MediaQuery.sizeOf(context).height;
    final heroHeight = (vh * 0.56).clamp(480.0, 720.0);

    final item = _featured[_index];
    return SizedBox(
      height: heroHeight + widget.topInset,
      child: Listener(
        // Trackpad two-finger horizontal swipe (macOS) — emitted as
        // PointerPanZoom events, NOT as regular pointer drags. We
        // accumulate the horizontal pan and step the carousel once
        // the total exceeds a small threshold, then reset so the
        // user can continue panning to advance further.
        behavior: HitTestBehavior.deferToChild,
        onPointerPanZoomStart: _featured.length < 2
            ? null
            : (_) => _panZoomDx = 0,
        onPointerPanZoomUpdate: _featured.length < 2
            ? null
            : (event) {
                _panZoomDx += event.panDelta.dx;
                if (_panZoomDx >= 60) {
                  _step(-1);
                  _panZoomDx = 0;
                } else if (_panZoomDx <= -60) {
                  _step(1);
                  _panZoomDx = 0;
                }
              },
        onPointerPanZoomEnd: _featured.length < 2
            ? null
            : (_) => _panZoomDx = 0,
        child: GestureDetector(
        // Mouse / touch horizontal drag steps the carousel.
        // `behavior: deferToChild` so the play button + page-dot taps
        // still receive their gestures; the drag recogniser only wins
        // when the user actually moves horizontally on empty hero area.
        behavior: HitTestBehavior.deferToChild,
        onHorizontalDragEnd: _featured.length < 2
            ? null
            : (details) {
                final v = details.primaryVelocity ?? 0;
                // 200 px/s threshold filters accidental nudges from
                // genuine swipes. Trackpad two-finger flicks (when
                // delivered as drags, not pan-zoom) land around
                // 600–1200.
                if (v > 200) {
                  _step(-1);
                } else if (v < -200) {
                  _step(1);
                }
              },
        child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Backdrop — crossfade between slides. Skipped when the
          // parent paints its own full-screen wallpaper, so the hero
          // image isn't drawn twice (the cause of the "image
          // repetition" the user reports on scroll: hero's bottom
          // gradient fades to dark, then the ambient wallpaper
          // re-asserts the same image below — looks like a seam).
          if (!widget.transparentBackdrop)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _HeroBackdrop(
                key: ValueKey<String>(_idOf(item)),
                item: item,
              ),
            ),
          // No full-hero darken layer when [transparentBackdrop] is
          // true. The previous bottom-up gradient created a visible
          // horizontal seam at the hero's edge and darkened the whole
          // upper half of the wallpaper uniformly. Title legibility
          // now comes from text drop-shadows on the foreground block
          // (cf. `_HeroForeground`).

          // Foreground bottom-left — pure crossfade. The previous
          // 600 ms slide-and-fade left the old + new title both
          // visible at the same x position for ~300 ms, reading as
          // a "ghost" letterform behind the headline. Shorter,
          // opacity-only swap keeps the rotation legible.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _HeroForeground(
              key: ValueKey<String>('fg_${_idOf(item)}'),
              item: item,
              topInset: widget.topInset,
              onPlay: () => widget.onPlayItem(item),
            ),
          ),

          // Page dots — only if multiple featured items.
          if (_featured.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: DS.space.lg,
              child: Center(
                child: _PageDots(
                  count: _featured.length,
                  active: _index,
                  onTap: (i) {
                    setState(() => _index = i);
                    _emitCurrent();
                    _restartTimer();
                  },
                ),
              ),
            ),

          // Side affordances: arrow buttons on desktop, hover-only.
          // Tap = step the carousel. Auto-rotation timer resets on each
          // user-driven advance so the user isn't fighting the clock.
          Align(
            alignment: Alignment.centerLeft,
            child: _SideArrow(icon: Icons.chevron_left, onTap: () => _step(-1)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _SideArrow(icon: Icons.chevron_right, onTap: () => _step(1)),
          ),
        ],
        ),
        ),
      ),
    );
  }
}

/// `StatelessWidget` + `Consumer(builder)` rather than a direct
/// `ConsumerWidget`. The `Consumer` wraps a Builder whose Element is
/// properly anchored inside this subtree — fixes the framework
/// assertion `ancestor == this` thrown at startup when an
/// `AnimatedSwitcher` reparents a `ConsumerWidget` mid-build.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({super.key, required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final cfg = ref.watch(tmdbConfigProvider);
      final tmdb = cfg.isActive
          ? ref.watch(tmdbLookupProvider(TmdbLookup(
              rawTitle: getStreamName(item),
              kind: item is SeriesItem ? TmdbKind.tv : TmdbKind.movie,
            )))
          : const AsyncValue<TmdbResult?>.data(null);
      final backdropUrl =
          TmdbService.image(tmdb.valueOrNull?.backdropPath, size: 'original') ??
              getStreamIcon(item);

      return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: AppColors.darkBackground),
        if (backdropUrl.isNotEmpty)
          // Sharp backdrop — no `ImageFilter.blur`. Flutter's sigma
          // units don't map 1:1 to SwiftUI's `.blur(radius:)`, so the
          // tvOS-inspired 8 px blur reads as a much heavier muddiness
          // in Flutter. Keep the slight scale-up for visual depth and
          // a small opacity drop so the title block sits cleanly over
          // the image.
          Transform.scale(
            scale: 1.06,
            child: Opacity(
              opacity: 0.95,
              child: CachedNetworkImage(
                imageUrl: backdropUrl,
                cacheManager: AppCacheManager.instance,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        // No darken gradient. Title legibility comes from the
        // double-shadow on the foreground text (cf. `_HeroForeground`).
        // Any global darken — even partial — produced a visible band
        // at the bottom of the hero before the next row.
        // Subtle brand wash bottom-left.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.9),
              radius: 1.2,
              colors: <Color>[
                AppColors.primaryBlue.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
      );
    });
  }
}

/// Same Consumer-builder pattern as `_HeroBackdrop`: avoids the
/// AnimatedSwitcher + ConsumerWidget reparent assertion at startup.
class _HeroForeground extends StatelessWidget {
  const _HeroForeground({
    super.key,
    required this.item,
    required this.topInset,
    required this.onPlay,
  });

  final dynamic item;
  final double topInset;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
    final name = getStreamName(item).cleanedTitleNoYear;
    final rating = item is VodItem
        ? item.rating
        : item is SeriesItem
            ? item.rating
            : null;

    final cfg = ref.watch(tmdbConfigProvider);
    final tmdb = cfg.isActive
        ? ref.watch(tmdbLookupProvider(TmdbLookup(
            rawTitle: getStreamName(item),
            kind: item is SeriesItem ? TmdbKind.tv : TmdbKind.movie,
          )))
        : const AsyncValue<TmdbResult?>.data(null);
    final providerPlot = item is VodItem
        ? (item.plot ?? item.description)
        : item is SeriesItem
            ? item.plot
            : null;
    final plot = (providerPlot != null && providerPlot.trim().isNotEmpty)
        ? providerPlot
        : (tmdb.valueOrNull?.overview ?? '');

    final l10n = AppLocalizations.of(context)!;
    final isSeries = item is SeriesItem;
    final badgeLabel = isSeries ? l10n.labelSerie : l10n.labelFilm;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DS.padding.screenHorizontal + DS.space.lg,
        topInset + DS.space.xxl,
        DS.padding.screenHorizontal + DS.space.lg,
        DS.padding.contentBottom + DS.space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          // "À la une" pill + badge label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DS.space.sm,
                  vertical: DS.space.xxs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(DS.radius.pill),
                ),
                child: Text(
                  l10n.aLaUne,
                  style: DSText.label.copyWith(color: Colors.white),
                ),
              ),
              SizedBox(width: DS.space.sm),
              Text(
                badgeLabel,
                style: DSText.label.copyWith(
                  color: DS.colour.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: DS.space.md),

          // Title — double-shadow (soft halo + crisp drop) so the
          // text stays legible on busy artwork without needing a
          // dark overlay across the hero.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DSText.displayHero.copyWith(
                color: Colors.white,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black, blurRadius: 28),
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: DS.space.xs),

          // Rating
          if (rating != null && rating.isNotEmpty && rating != '0')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.star, size: 16, color: AppColors.warning),
                SizedBox(width: DS.space.xxs),
                Text(
                  rating,
                  style: DSText.caption.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                ),
              ],
            ),

          if (plot.isNotEmpty) ...<Widget>[
            SizedBox(height: DS.space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Text(
                plot,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: DSText.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black87, blurRadius: 18),
                    Shadow(
                      color: Colors.black,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: DS.space.md),
          PrimaryHeroButton(
            label: isSeries ? l10n.voirLaSerie : l10n.regarder,
            icon: Icons.play_arrow,
            onPressed: onPlay,
          ),
        ],
      ),
      );
    });
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.active,
    required this.onTap,
  });

  final int count;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (i) {
        final isActive = i == active;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.space.xxs),
          child: GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: DS.motion.standard,
              curve: DS.motion.curve,
              width: isActive ? 28 : 8,
              height: 5,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryBlueLighter
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Hover-revealed side arrows for stepping the carousel on desktop.
/// Idle = invisible, hover = soft black puck with chevron. Tap fires
/// the supplied callback.
class _SideArrow extends StatefulWidget {
  const _SideArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SideArrow> createState() => _SideArrowState();
}

class _SideArrowState extends State<_SideArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: DS.motion.quick,
          opacity: _hovered ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.all(DS.space.md),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryBlue.withValues(alpha: 0.10),
            AppColors.darkBackground.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

String _idOf(dynamic item) {
  // VodItem.id is exposed via an extension (`VodItemX`) — extensions
  // are resolved against the *static* type, not the runtime one, so
  // `item.id` on a `dynamic`-typed reference would throw
  // NoSuchMethodError. Read `streamId` directly off the typed
  // promoted variable.
  if (item is VodItem) return 'vod_${item.streamId}';
  if (item is SeriesItem) return 'series_${item.seriesId}';
  return identityHashCode(item).toString();
}
