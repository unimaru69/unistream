import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/core/theme_colors.dart';
import '../../../core/cache_config.dart';
import '../../../core/colors.dart';
import '../../../models/content_mode.dart';
import '../../../models/continue_watching_item.dart';
import '../../../utils/stream_helpers.dart';

/// Horizontal carousel of "Continue watching" items with type badges.
class ContinueWatchingRow extends StatelessWidget {
  final List<ContinueWatchingItem> items;
  final void Function(ContinueWatchingItem item) onTap;

  /// When true and [items] is empty, show a friendly placeholder instead of
  /// hiding the whole section. Mirrors the tvOS UX. Default: true (Home);
  /// pass false inside tight layouts (split views) where clutter matters.
  final bool showsPlaceholder;

  /// Fires `(item, true)` on tile-enter, `(item, false)` on tile-exit.
  /// Used by Accueil to drive an ambient-wallpaper override; safe to
  /// omit on surfaces where hover preview isn't wanted.
  final void Function(ContinueWatchingItem item, bool isHovered)? onItemHover;

  const ContinueWatchingRow({
    super.key,
    required this.items,
    required this.onTap,
    this.showsPlaceholder = true,
    this.onItemHover,
  });

  static const _modeBadges = {
    'live': (label: 'LIVE', color: Colors.redAccent, icon: Icons.circle),
    'vod': (label: 'FILM', color: AppColors.primaryBlue, icon: Icons.movie),
    'series': (label: 'SERIE', color: AppColors.accentGreen, icon: Icons.tv),
  };

  /// Filter rule matching the tvOS behaviour:
  /// - films (`vod`): keep 0.5% < ratio < 95% — a finished film isn't "in progress"
  /// - episodes (`series`): skip finished, AND collapse to one tile per
  ///   series (the most recent unfinished episode). Before this dedupe, a
  ///   binge-watched series produced one tile per episode and spammed the
  ///   row with twelve "Like Me" cards.
  /// - live: always keep
  ///
  /// Series dedupe key, with fallback chain:
  ///   1. `cover` URL if non-empty — same series episodes share the
  ///      parent series' cover (`series_detail_screen` passes
  ///      `widget.cover` to `saveMeta`).
  ///   2. Otherwise the extracted series-name prefix from `name`
  ///      (everything before the first " - ", `" S0"`/`" E0"` token,
  ///      `" (20"` for year suffix, etc.). Catches the case where the
  ///      meta was saved with an empty cover URL — without this all
  ///      episodes of e.g. "Drag Race France - SxxEyy" each become
  ///      their own tile.
  /// Items are already sorted by timestamp DESC by
  /// `WatchProgress.loadContinueWatching`, so the first encounter per
  /// key is the most recent.
  List<ContinueWatchingItem> get _filtered {
    final seenSeriesKeys = <String>{};
    final out = <ContinueWatchingItem>[];
    for (final i in items) {
      if (i.mode == 'vod') {
        if (i.ratio > 0.005 && i.ratio < 0.95) out.add(i);
        continue;
      }
      if (i.mode == 'series') {
        if (i.ratio <= 0.005 || i.ratio >= 0.95) continue;
        // Dedupe series episodes by **name prefix first** — covers
        // can drift between saves (a "Drag Race France" episode
        // watched via search vs. catalog vs. favourites can land
        // with three different cover URLs) so the name-based key is
        // the only reliable group. Cover URL is kept as a tiebreaker
        // when the name prefix collapses to nothing (e.g. an episode
        // titled just "Pilot" with no series prefix).
        final namePrefix = _seriesNamePrefix(i.name);
        final dedupeKey = namePrefix.isNotEmpty
            ? 'name:$namePrefix'
            : (i.cover.isNotEmpty ? 'cover:${i.cover}' : 'id:${i.id}');
        if (!seenSeriesKeys.add(dedupeKey)) continue;
        out.add(i);
        continue;
      }
      // Live: keep if any progress. Anything else (empty mode from a
      // corrupted meta blob, an unknown future mode value) is dropped
      // — without this guard, items where `saveMeta` was called with
      // an empty `mode` argument fall through the cracks and clutter
      // the row with play-icon-only tiles.
      if (i.mode == 'live' && i.ratio > 0.005) out.add(i);
    }
    return out;
  }

  /// Best-effort "strip the episode suffix off an episode title to get
  /// the series name". Walks `raw` left-to-right and stops at the
  /// first marker indicating that what follows is per-episode metadata
  /// rather than series name:
  ///   * " - "      — common separator before episode info
  ///   * " S0", " s0"  — "S0X" season marker
  ///   * " E0", " e0"  — "E0Y" episode marker (when no season prefix)
  ///   * " — "      — long-dash variant
  /// Returns the trimmed prefix lowercased so case differences don't
  /// split the same series across two tiles.
  static String _seriesNamePrefix(String raw) {
    final candidates = <int>[
      raw.indexOf(' - '),
      raw.indexOf(' — '),
      raw.indexOf(' S0'),
      raw.indexOf(' s0'),
      raw.indexOf(' E0'),
      raw.indexOf(' e0'),
    ].where((i) => i >= 0);
    final cut = candidates.isEmpty
        ? raw.length
        : candidates.reduce((a, b) => a < b ? a : b);
    return raw.substring(0, cut).trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final tc = AppThemeColors.of(context);

    if (filtered.isEmpty) {
      if (!showsPlaceholder) return const SizedBox.shrink();
      return _EmptyContinuePlaceholder();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(AppLocalizations.of(context)!.continuerRegarder,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: tc.textTertiary, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final item  = filtered[i];
            final badge = _modeBadges[item.mode];
            final isWatched = item.ratio > 0.95;
            return Semantics(
              label: '${item.name.isNotEmpty ? item.name : 'Contenu'}, ${(item.ratio * 100).round()}% regard\u00e9${badge != null ? ', ${badge.label}' : ''}',
              button: true,
              child: MouseRegion(
                onEnter: (_) => onItemHover?.call(item, true),
                onExit: (_) => onItemHover?.call(item, false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
              onTap: () => onTap(item),
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(fit: StackFit.expand, children: [
                      // Tile is 90 wide — `memCacheWidth: 90*dpr`
                      // resizes the TMDB poster down at decode time
                      // (file on disk stays original). Critical for
                      // long carousels — a 30-item Continue Watching
                      // row previously held ~70 MB of bitmap RAM,
                      // now ~3 MB.
                      item.cover.isNotEmpty
                          ? CachedNetworkImage(imageUrl: item.cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                              memCacheWidth:
                                  (90 * MediaQuery.devicePixelRatioOf(context)).round(),
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => ColoredBox(color: tc.inputFill),
                              errorWidget: (_, __, ___) =>
                                  _CoverFallback(name: item.name, tc: tc))
                          : _CoverFallback(name: item.name, tc: tc),
                      // Mode badge
                      if (badge != null)
                        Positioned(top: 4, left: 4,
                          child: ExcludeSemantics(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: badge.color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(badge.label,
                                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                          )),
                        ),
                      // "Vu" badge for watched episodes kept in the row.
                      if (isWatched)
                        Positioned(top: 4, right: 4,
                          child: ExcludeSemantics(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: const [
                              Icon(Icons.check, size: 9, color: Colors.white),
                              SizedBox(width: 2),
                              Text('Vu', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                            ]),
                          )),
                        ),
                      // Play overlay
                      ExcludeSemantics(child: Center(
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                        ),
                      )),
                      // Progress bar — green when watched, accent otherwise.
                      Positioned(bottom: 0, left: 0, right: 0,
                        child: ExcludeSemantics(child: LinearProgressIndicator(
                          value: item.ratio,
                          backgroundColor: tc.divider,
                          color: isWatched ? Colors.green : AppColors.primaryBlue,
                          minHeight: 3,
                        )),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 3),
                  ExcludeSemantics(child: Text(item.name, style: TextStyle(fontSize: 10, color: tc.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
              ),
            ),
            );
          },
        ),
      ),
      Divider(color: tc.divider, height: 1),
    ]);
  }
}

/// Placeholder shown in place of the Continue Watching row when there's
/// nothing in progress. Keeps the user aware the feature exists.
class _EmptyContinuePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(l10n.continuerRegarder,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: tc.textTertiary, letterSpacing: 0.8)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tc.textPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.play_circle_outline, color: tc.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rien en cours pour le moment',
                      style: TextStyle(fontSize: 13, color: tc.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Les films et épisodes que vous regardez apparaîtront ici.',
                      style: TextStyle(fontSize: 11, color: tc.textTertiary)),
                ],
              ),
            ),
          ]),
        ),
      ),
      Divider(color: tc.divider, height: 1),
    ]);
  }
}

/// Tile background drawn when an item has no cover URL (or the network
/// fetch errored). Instead of a generic film icon on a flat fill — which
/// makes the whole carousel look broken when many entries lack covers
/// (common for series episodes saved before the series cover was
/// resolved) — we paint a vertical brand gradient and lay the item's
/// name (or extracted series-name prefix) in a small caps label. Users
/// can still recognise what they're about to resume.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.name, required this.tc});

  final String name;
  final AppThemeColors tc;

  @override
  Widget build(BuildContext context) {
    final label = _ContinueWatchingRowLabel.shorten(name);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tc.inputFill,
            tc.surfaceAlt,
          ],
        ),
      ),
      child: Padding(
        // Name pinned to the top of the tile so the central play-icon
        // overlay (drawn one Stack-layer above) doesn't sit on top of
        // the text. Bottom 22% reserved for the progress bar.
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 22),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper namespace just to keep the label-shortening logic next to
/// the dedup heuristic without exposing it on `ContinueWatchingRow`'s
/// public surface. Mirrors `_seriesNamePrefix` in spirit but keeps the
/// case + a touch more text so the user can recognise the title.
class _ContinueWatchingRowLabel {
  static String shorten(String raw) {
    // Reuse the same cut points as `_seriesNamePrefix` so the
    // fallback label = the same series name we deduped on.
    final candidates = <int>[
      raw.indexOf(' - '),
      raw.indexOf(' — '),
      raw.indexOf(' S0'),
      raw.indexOf(' s0'),
      raw.indexOf(' E0'),
      raw.indexOf(' e0'),
    ].where((i) => i >= 0);
    final cut = candidates.isEmpty
        ? raw.length
        : candidates.reduce((a, b) => a < b ? a : b);
    final trimmed = raw.substring(0, cut).trim();
    return trimmed.isEmpty ? raw : trimmed;
  }
}

/// Horizontal carousel of "Recently added" items.
class RecentlyAddedRow extends StatelessWidget {
  final List<dynamic> items;
  final ContentMode mode;
  final void Function(dynamic item) onTap;

  /// Optional hover callback — fires `(item, true)` on enter and
  /// `(item, false)` on exit. Used by the Accueil to drive an
  /// ambient-wallpaper override. Safe to omit.
  final void Function(dynamic item, bool isHovered)? onItemHover;

  const RecentlyAddedRow({
    super.key,
    required this.items,
    required this.mode,
    required this.onTap,
    this.onItemHover,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || mode == ContentMode.live) return const SizedBox.shrink();
    final tc = AppThemeColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(AppLocalizations.of(context)!.recemmentAjoutes,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: tc.textTertiary, letterSpacing: 0.8)),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final cover = getStreamIcon(item);
            final name = getStreamName(item);
            return Semantics(
              label: name.isNotEmpty ? name : 'Contenu',
              button: true,
              child: MouseRegion(
                onEnter: (_) => onItemHover?.call(item, true),
                onExit: (_) => onItemHover?.call(item, false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(fit: StackFit.expand, children: [
                        if (cover.isNotEmpty)
                          CachedNetworkImage(imageUrl: cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                              memCacheWidth:
                                  (90 * MediaQuery.devicePixelRatioOf(context)).round(),
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => ColoredBox(color: tc.inputFill),
                              errorWidget: (_, __, ___) => Container(color: tc.inputFill,
                                  child: Icon(Icons.fiber_new, color: tc.borderColor)))
                        else
                          Container(color: tc.inputFill,
                              child: Icon(Icons.fiber_new, color: tc.borderColor)),
                        // tvOS-style "NOUVEAU" pill — top-left so it
                        // doesn't fight focus rings (which sit on the
                        // right) and stays legible over any cover art.
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentWarm,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.badgeNouveau,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    )),
                    const SizedBox(height: 3),
                    ExcludeSemantics(child: Text(name, style: TextStyle(fontSize: 10, color: tc.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
              ),
            );
          },
        ),
      ),
      Divider(color: tc.divider, height: 1),
    ]);
  }
}
