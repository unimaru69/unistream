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

  const ContinueWatchingRow({
    super.key,
    required this.items,
    required this.onTap,
    this.showsPlaceholder = true,
  });

  static const _modeBadges = {
    'live': (label: 'LIVE', color: Colors.redAccent, icon: Icons.circle),
    'vod': (label: 'FILM', color: AppColors.primaryBlue, icon: Icons.movie),
    'series': (label: 'SERIE', color: AppColors.accentGreen, icon: Icons.tv),
  };

  /// Filter rule matching the tvOS behaviour:
  /// - films (`vod`): keep 0.5% < ratio < 95% — a finished film isn't "in progress"
  /// - episodes (`series`): keep any ratio > 0.5% — a series with watched
  ///   episodes stays visible so you can jump back in
  /// - live: always keep
  List<ContinueWatchingItem> get _filtered {
    return items.where((i) {
      if (i.mode == 'vod') return i.ratio > 0.005 && i.ratio < 0.95;
      return i.ratio > 0.005;
    }).toList();
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
              child: GestureDetector(
              onTap: () => onTap(item),
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(fit: StackFit.expand, children: [
                      item.cover.isNotEmpty
                          ? CachedNetworkImage(imageUrl: item.cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => ColoredBox(color: tc.inputFill),
                              errorWidget: (_, __, ___) => Container(color: tc.inputFill,
                                  child: Icon(Icons.movie, color: tc.borderColor)))
                          : Container(color: tc.inputFill,
                              child: Icon(Icons.movie, color: tc.borderColor)),
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

/// Horizontal carousel of "Recently added" items.
class RecentlyAddedRow extends StatelessWidget {
  final List<dynamic> items;
  final ContentMode mode;
  final void Function(dynamic item) onTap;

  const RecentlyAddedRow({
    super.key,
    required this.items,
    required this.mode,
    required this.onTap,
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
              child: GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: cover.isNotEmpty
                          ? CachedNetworkImage(imageUrl: cover, cacheManager: AppCacheManager.instance, fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => ColoredBox(color: tc.inputFill),
                              errorWidget: (_, __, ___) => Container(color: tc.inputFill,
                                  child: Icon(Icons.fiber_new, color: tc.borderColor)))
                          : Container(color: tc.inputFill,
                              child: Icon(Icons.fiber_new, color: tc.borderColor)),
                    )),
                    const SizedBox(height: 3),
                    ExcludeSemantics(child: Text(name, style: TextStyle(fontSize: 10, color: tc.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
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
