import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache_config.dart';
import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';
import '../../../models/channel.dart';
import '../../../models/content_mode.dart';
import '../../../models/series_item.dart';
import '../../../models/vod_item.dart';
import '../../../providers/live_epg_preview_provider.dart';
import '../../../providers/tmdb_provider.dart';
import '../../../services/tmdb_service.dart';
import '../../../services/xtream_api.dart';
import '../../../utils/stream_helpers.dart';
import '../../../utils/title_formatting.dart';

/// Bottom-of-grid preview panel mirroring
/// `tvos/.../Components/FocusedItemPreview.swift` (VOD / Séries) and
/// `tvos/.../Live/LiveFocusedPreview.swift` (Live).
///
/// Pinned to the bottom of the grid (parent renders it inside a
/// `Stack` with the grid above). Animates in/out as the user hovers
/// tiles. Soft transparent → dark gradient background so the grid
/// keeps showing through the top of the panel.
///
/// Pass `null` as [item] to dismiss the panel.
class FocusedItemPreview extends ConsumerWidget {
  const FocusedItemPreview({
    super.key,
    required this.item,
    required this.mode,
  });

  final dynamic item;
  final ContentMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: DS.motion.standard,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: item == null
          ? const SizedBox.shrink(key: ValueKey<String>('empty'))
          : _Panel(
              key: ValueKey<String>(getStreamId(item)),
              item: item,
              mode: mode,
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.item, required this.mode});

  final dynamic item;
  final ContentMode mode;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        // Asymmetric padding: generous lead-in on top so the gradient
        // has room to dissolve up into the grid, modest bottom so the
        // content sits comfortably above the screen edge.
        padding: EdgeInsets.fromLTRB(
          DS.padding.screenHorizontal,
          DS.space.xxl,
          DS.padding.screenHorizontal,
          DS.space.md,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: <double>[0.0, 0.12, 0.55, 1.0],
            colors: <Color>[
              Color(0x00000000),
              Color(0x73000000),
              Color(0xEB000000),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: mode == ContentMode.live
                  ? _LiveContent(item: item)
                  : _VodSeriesContent(item: item, mode: mode),
            ),
            SizedBox(width: DS.space.lg),
            _Cover(item: item, mode: mode),
          ],
        ),
      ),
    );
  }
}

class _VodSeriesContent extends ConsumerWidget {
  const _VodSeriesContent({required this.item, required this.mode});

  final dynamic item;
  final ContentMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = getStreamName(item);
    final providerRating = item is VodItem
        ? item.rating
        : item is SeriesItem
            ? item.rating
            : null;

    final cfg = ref.watch(tmdbConfigProvider);
    final tmdb = cfg.isActive
        ? ref.watch(tmdbLookupProvider(TmdbLookup(
            rawTitle: name,
            kind: mode == ContentMode.vod ? TmdbKind.movie : TmdbKind.tv,
          )))
        : const AsyncValue<TmdbResult?>.data(null);

    final ratingNumeric = formattedRating(tmdb.valueOrNull?.rating);
    final ratingText = ratingNumeric.isNotEmpty
        ? ratingNumeric
        : ((providerRating ?? '').isNotEmpty && providerRating != '0'
            ? providerRating!
            : '');
    final year = tmdb.valueOrNull?.year?.toString() ?? '';
    final synopsis = tmdb.valueOrNull?.overview ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name.cleanedTitleNoYear,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DSText.title2.copyWith(color: Colors.white),
        ),
        if (ratingText.isNotEmpty || year.isNotEmpty) ...<Widget>[
          SizedBox(height: DS.space.xs),
          _MetadataStrip(rating: ratingText, year: year),
        ],
        SizedBox(height: DS.space.sm),
        SizedBox(
          height: 72,
          child: synopsis.isNotEmpty
              ? Text(
                  synopsis,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.body.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                )
              : tmdb.isLoading
                  ? Text(
                      'Chargement de la synopsis…',
                      style: DSText.caption.copyWith(
                        color: DS.colour.textTertiary,
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LiveContent extends ConsumerWidget {
  const _LiveContent({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item is! Channel) return const SizedBox.shrink();
    final ch = item as Channel;
    final numStr = ch.num?.toString() ?? '';
    final snapshot = ref
            .watch(liveEpgPreviewProvider(ch.id))
            .valueOrNull ??
        const LiveEpgSnapshot();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Channel line — small label above the headline.
        Row(
          children: <Widget>[
            if (numStr.isNotEmpty) ...<Widget>[
              Text(
                numStr,
                style: DSText.label.copyWith(color: DS.colour.textTertiary),
              ),
              SizedBox(width: DS.space.xs),
            ],
            Flexible(
              child: Text(
                ch.name.cleanedTitleNoYear,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DSText.title3.copyWith(
                  color: DS.colour.textSecondary,
                ),
              ),
            ),
            if (ch.hasCatchup) ...<Widget>[
              SizedBox(width: DS.space.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentWarm,
                  borderRadius: BorderRadius.circular(DS.radius.pill),
                ),
                child: const Text(
                  'REPLAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: DS.space.xs),
        // Headline + EPG block. Reserves a fixed-ish vertical slot so
        // the panel doesn't jump when the EPG snapshot resolves.
        SizedBox(
          height: 84,
          child: _LiveProgrammeBlock(channel: ch, snapshot: snapshot),
        ),
        if (snapshot.next != null)
          _NextProgrammeLine(entry: snapshot.next!),
      ],
    );
  }
}

class _LiveProgrammeBlock extends StatelessWidget {
  const _LiveProgrammeBlock({
    required this.channel,
    required this.snapshot,
  });

  final Channel channel;
  final LiveEpgSnapshot snapshot;

  static String _fmtTime(DateTime d) {
    final local = d.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final prog = snapshot.now;
    if (prog == null) {
      // No EPG resolved yet — fall back to channel headline + category
      // line so the panel isn't blank during the cache-miss → fetch
      // round trip (or for channels the provider doesn't surface EPG
      // for: sports, music, etc.).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            channel.name.cleanedTitleNoYear,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSText.title2.copyWith(color: Colors.white),
          ),
          SizedBox(height: DS.space.xs),
          if ((channel.categoryName ?? '').isNotEmpty)
            Text(
              channel.categoryName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSText.body.copyWith(color: DS.colour.textTertiary),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          prog.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DSText.title2.copyWith(color: Colors.white),
        ),
        SizedBox(height: DS.space.xs),
        Row(
          children: <Widget>[
            Text(
              '${_fmtTime(prog.start)} – ${_fmtTime(prog.end)}',
              style: DSText.caption.copyWith(color: DS.colour.textTertiary),
            ),
            SizedBox(width: DS.space.sm),
            // "EN DIRECT" pulse — accent-warm dot + label.
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accentWarm,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: DS.space.xxs),
            Text(
              'EN DIRECT',
              style: DSText.caption.copyWith(
                color: AppColors.accentWarm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: DS.space.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DS.radius.tag),
            child: LinearProgressIndicator(
              value: prog.progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentWarm,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NextProgrammeLine extends StatelessWidget {
  const _NextProgrammeLine({required this.entry});

  final EpgPreviewEntry entry;

  static String _fmtTime(DateTime d) {
    final local = d.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.space.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.arrow_forward,
              size: 11, color: DS.colour.textTertiary),
          SizedBox(width: DS.space.xxs),
          Flexible(
            child: Text(
              'Ensuite : ${entry.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSText.caption.copyWith(color: DS.colour.textTertiary),
            ),
          ),
          SizedBox(width: DS.space.xs),
          Text(
            '· ${_fmtTime(entry.start)}',
            style: DSText.caption.copyWith(color: DS.colour.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item, required this.mode});

  final dynamic item;
  final ContentMode mode;

  @override
  Widget build(BuildContext context) {
    final url = getStreamIcon(item);
    // Live shows a wider 16:9-ish art (channel logo / backdrop). VOD
    // / Series uses a portrait 2:3 mini-poster.
    final size = mode == ContentMode.live
        ? const Size(160, 90)
        : const Size(80, 120);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DS.radius.card),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                cacheManager: AppCacheManager.instance,
                fit: mode == ContentMode.live
                    ? BoxFit.contain
                    : BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.darkSurface),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.darkSurface,
                  child: Icon(
                    mode == ContentMode.live
                        ? Icons.live_tv
                        : mode == ContentMode.series
                            ? Icons.tv
                            : Icons.movie,
                    color: DS.colour.textTertiary,
                  ),
                ),
              )
            : Container(
                color: AppColors.darkSurface,
                child: Icon(
                  mode == ContentMode.live
                      ? Icons.live_tv
                      : mode == ContentMode.series
                          ? Icons.tv
                          : Icons.movie,
                  color: DS.colour.textTertiary,
                ),
              ),
      ),
    );
  }
}

class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({required this.rating, required this.year});

  final String rating;
  final String year;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (rating.isNotEmpty) ...<Widget>[
          Icon(Icons.star, size: 14, color: AppColors.warning),
          SizedBox(width: DS.space.xxs),
          Text(
            rating,
            style: DSText.bodyEmphasised.copyWith(
              color: DS.colour.textSecondary,
            ),
          ),
        ],
        if (year.isNotEmpty) ...<Widget>[
          if (rating.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DS.space.xs),
              child: Text(
                '·',
                style: DSText.bodyEmphasised.copyWith(
                  color: DS.colour.textTertiary,
                ),
              ),
            ),
          Text(
            year,
            style: DSText.bodyEmphasised.copyWith(
              color: DS.colour.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
