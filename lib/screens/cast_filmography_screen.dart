import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache_config.dart';
import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../core/typography.dart';
import '../l10n/app_localizations.dart';
import '../models/series_item.dart';
import '../providers/tmdb_person_provider.dart';
import '../services/catalog_index.dart';
import '../services/tmdb_service.dart';
import '../utils/routes.dart';
import '../utils/title_formatting.dart';
import '../widgets/tmdb_badge.dart';
import 'series_detail_screen.dart';
import 'vod/vod_detail_screen.dart';

/// Cast filmography screen — opened by tapping a card in
/// `TmdbCastRow`. Mirror of
/// `tvos/UniStreamTV/UniStreamTV/Views/Components/CastFilmographyView.swift`.
///
/// Header: portrait + name + bio. Two sections (Films / Séries),
/// each a grid of credit cards. Cards that resolve against the local
/// Xtream catalogue open the corresponding detail screen; the rest
/// dim and show a "Pas dans votre catalogue" hint.
class CastFilmographyScreen extends ConsumerStatefulWidget {
  const CastFilmographyScreen({
    super.key,
    required this.personId,
    required this.initialName,
    this.initialProfilePath,
  });

  final int personId;
  final String initialName;
  final String? initialProfilePath;

  @override
  ConsumerState<CastFilmographyScreen> createState() =>
      _CastFilmographyScreenState();
}

class _CastFilmographyScreenState extends ConsumerState<CastFilmographyScreen> {
  @override
  void initState() {
    super.initState();
    // Warm both catalog indexes in parallel — the user might tap any
    // film or series and the warmup hides the "Indexation…" delay on
    // first interaction.
    final idx = ref.read(catalogIndexProvider);
    idx.warmupIfNeeded(CatalogKind.movie);
    idx.warmupIfNeeded(CatalogKind.tv);
  }

  void _openCredit(TmdbPersonCredit credit, AppLocalizations l10n) {
    final idx = ref.read(catalogIndexProvider);
    final match = idx.match(
      credit.title,
      credit.mediaType == TmdbKind.movie
          ? CatalogKind.movie
          : CatalogKind.tv,
    );
    switch (match) {
      case CatalogMatchVod(:final item):
        Navigator.push(
          context,
          slideRoute(VodDetailScreen(vod: item)),
        );
      case CatalogMatchSeries(:final item):
        Navigator.push(
          context,
          slideRoute(SeriesDetailScreen(
            seriesId: item.id,
            title: item.name,
            cover: item.displayIcon,
            rating: item.rating,
            categoryName: item.categoryName,
          )),
        );
      case CatalogMatchNotFound():
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkSurface,
            title: Text(
              l10n.pasDansVotreCatalogue,
              style: DSText.title3.copyWith(color: Colors.white),
            ),
            content: Text(
              l10n.titreIndisponible,
              style: DSText.body.copyWith(color: DS.colour.textSecondary),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bundle = ref.watch(tmdbPersonProvider(widget.personId));
    final loaded = bundle.valueOrNull;
    final isLoading = bundle.isLoading && loaded == null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DS.padding.screenHorizontal,
            DS.space.lg,
            DS.padding.screenHorizontal,
            DS.padding.contentBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(
                name: loaded?.details?.name ?? widget.initialName,
                department: loaded?.details?.knownForDepartment,
                biography: loaded?.details?.biography,
                profilePath: loaded?.details?.profilePath ??
                    widget.initialProfilePath,
              ),
              SizedBox(height: DS.padding.sectionGap),
              if (isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: DS.space.xxl),
                    child: CircularProgressIndicator(
                      color: DS.colour.textPrimary,
                    ),
                  ),
                )
              else ...<Widget>[
                if ((loaded?.movies.isNotEmpty ?? false))
                  _CreditSection(
                    title: l10n.vod,
                    credits: loaded!.movies,
                    kind: TmdbKind.movie,
                    onTap: (c) => _openCredit(c, l10n),
                  ),
                if ((loaded?.tv.isNotEmpty ?? false))
                  Padding(
                    padding: EdgeInsets.only(top: DS.padding.sectionGap),
                    child: _CreditSection(
                      title: l10n.series,
                      credits: loaded!.tv,
                      kind: TmdbKind.tv,
                      onTap: (c) => _openCredit(c, l10n),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.department,
    required this.biography,
    required this.profilePath,
  });

  final String name;
  final String? department;
  final String? biography;
  final String? profilePath;

  @override
  Widget build(BuildContext context) {
    final portraitUrl = TmdbService.image(profilePath, size: 'h632');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Portrait(url: portraitUrl),
        SizedBox(width: DS.space.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DSText.display.copyWith(color: Colors.white),
              ),
              if ((department ?? '').isNotEmpty) ...<Widget>[
                SizedBox(height: DS.space.xs),
                Text(
                  department!,
                  style: DSText.bodyEmphasised.copyWith(
                    color: AppColors.primaryBlueLighter,
                  ),
                ),
              ],
              if ((biography ?? '').isNotEmpty) ...<Widget>[
                SizedBox(height: DS.space.md),
                Text(
                  biography!,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.body.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: DS.space.sm),
              const TmdbBadge(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    Widget placeholder() => Container(
          width: size,
          height: size,
          color: AppColors.darkSurface,
          child: Icon(
            Icons.person,
            size: 88,
            color: DS.colour.textTertiary,
          ),
        );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                cacheManager: AppCacheManager.instance,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder(),
                errorWidget: (_, __, ___) => placeholder(),
              )
            : placeholder(),
      ),
    );
  }
}

class _CreditSection extends ConsumerWidget {
  const _CreditSection({
    required this.title,
    required this.credits,
    required this.kind,
    required this.onTap,
  });

  final String title;
  final List<TmdbPersonCredit> credits;
  final TmdbKind kind;
  final void Function(TmdbPersonCredit) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(catalogIndexProvider);
    final state = kind == TmdbKind.movie ? idx.movieState : idx.seriesState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: DSText.title1.copyWith(color: Colors.white),
            ),
            SizedBox(width: DS.space.sm),
            Text(
              '${credits.length}',
              style: DSText.body.copyWith(color: DS.colour.textTertiary),
            ),
            const Spacer(),
            ValueListenableBuilder<CatalogLoadState>(
              valueListenable: state,
              builder: (_, value, __) => value == CatalogLoadState.loading
                  ? _IndexingHint()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        SizedBox(height: DS.space.md),
        LayoutBuilder(builder: (context, constraints) {
          const targetTileWidth = 180.0;
          final columns =
              (constraints.maxWidth / (targetTileWidth + 16))
                  .floor()
                  .clamp(2, 8);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 180 / 320,
              crossAxisSpacing: DS.space.md,
              mainAxisSpacing: DS.space.lg,
            ),
            itemCount: credits.length,
            itemBuilder: (_, i) {
              final credit = credits[i];
              final match = idx.match(
                credit.title,
                kind == TmdbKind.movie
                    ? CatalogKind.movie
                    : CatalogKind.tv,
              );
              final isAvailable = match is! CatalogMatchNotFound;
              return _CreditCard(
                credit: credit,
                isAvailable: isAvailable,
                onTap: () => onTap(credit),
              );
            },
          );
        }),
      ],
    );
  }
}

class _IndexingHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: DS.colour.textTertiary,
          ),
        ),
        SizedBox(width: DS.space.xs),
        Text(
          l10n.indexationCatalogue,
          style: DSText.caption.copyWith(color: DS.colour.textTertiary),
        ),
      ],
    );
  }
}

class _CreditCard extends StatefulWidget {
  const _CreditCard({
    required this.credit,
    required this.isAvailable,
    required this.onTap,
  });

  final TmdbPersonCredit credit;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  State<_CreditCard> createState() => _CreditCardState();
}

class _CreditCardState extends State<_CreditCard> {
  bool _hovered = false;

  void _setHover(bool v) {
    if (_hovered == v || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.credit.posterUrl();
    final isAvailable = widget.isAvailable;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AnimatedScale(
                scale: _hovered ? DS.focus.chipScale : 1.0,
                duration: DS.focus.animation,
                curve: DS.focus.curve,
                child: AnimatedContainer(
                  duration: DS.focus.animation,
                  curve: DS.focus.curve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DS.radius.card),
                    boxShadow: _hovered
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: DS.focus.shadowOpacity,
                              ),
                              blurRadius: DS.focus.shadowRadius,
                              offset: Offset(0, DS.focus.shadowY),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radius.card),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (url != null)
                          CachedNetworkImage(
                            imageUrl: url,
                            cacheManager: AppCacheManager.instance,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.darkSurface),
                            errorWidget: (_, __, ___) => _PosterPlaceholder(
                                kind: widget.credit.mediaType),
                          )
                        else
                          _PosterPlaceholder(kind: widget.credit.mediaType),
                        if (!isAvailable) ...<Widget>[
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                          Padding(
                            padding: EdgeInsets.all(DS.space.sm),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                AppLocalizations.of(context)!
                                    .pasDansVotreCatalogue,
                                style: DSText.label.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: DS.space.xs),
            Text(
              widget.credit.title.cleanedTitleNoYear,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSText.title3.copyWith(
                color: isAvailable
                    ? DS.colour.textPrimary
                    : DS.colour.textTertiary,
              ),
            ),
            SizedBox(height: 2),
            Row(
              children: <Widget>[
                if (widget.credit.year != null)
                  Text(
                    '${widget.credit.year}',
                    style: DSText.caption.copyWith(
                      color: DS.colour.textTertiary,
                    ),
                  ),
                if (widget.credit.year != null &&
                    (widget.credit.character ?? '').isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: DS.space.xxs),
                    child: Text(
                      '·',
                      style: DSText.caption.copyWith(
                        color: DS.colour.textTertiary,
                      ),
                    ),
                  ),
                if ((widget.credit.character ?? '').isNotEmpty)
                  Expanded(
                    child: Text(
                      widget.credit.character!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSText.caption.copyWith(
                        color: DS.colour.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.kind});

  final TmdbKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurface,
      child: Center(
        child: Icon(
          kind == TmdbKind.movie ? Icons.movie : Icons.tv,
          size: 36,
          color: DS.colour.textTertiary,
        ),
      ),
    );
  }
}
