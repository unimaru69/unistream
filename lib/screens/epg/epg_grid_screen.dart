import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/design_tokens.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/core/typography.dart';
import 'package:unistream/l10n/app_localizations.dart';

import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../models/parsed_epg_program.dart';
import '../../providers/favorites_provider.dart';
import '../../repositories/content_repository.dart';
import '../../services/epg_reminder_service.dart';
import '../../utils/api_error_localizer.dart';
import '../../utils/routes.dart';
import '../../utils/title_formatting.dart';
import '../player/player_screen.dart';

/// Apple-TV+-style Guide TV. Mirror of
/// `tvos/UniStreamTV/UniStreamTV/Views/EPG/EPGGridView.swift` (option B
/// layout): one row per channel, programmes laid out in a horizontal
/// scroll inside each row. Banner left (logo + name + replay badge),
/// programme lane right.
///
/// Replaces the previous 2-D pixel-time grid — simpler to read on
/// desktop, robust on narrow viewports, no scroll-sync gymnastics.
class EpgGridScreen extends ConsumerStatefulWidget {
  const EpgGridScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<EpgGridScreen> createState() => _EpgGridScreenState();
}

class _EpgGridScreenState extends ConsumerState<EpgGridScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);

  // ── State ──
  List<cat.Category> _categories = const <cat.Category>[];
  List<Channel> _allChannels = const <Channel>[]; // full list (lazy-load)
  bool _allChannelsLoaded = false;
  Map<String, List<ParsedEpgProgram>> _epgData = const <String, List<ParsedEpgProgram>>{};

  /// Filter id. `__favorites__` / `__all__` / `<categoryId>`.
  String _filter = '__favorites__';
  DateTime _selectedDay = DateTime.now();
  String _searchQuery = '';
  bool _isSearchActive = false;
  String? _toast;
  Timer? _toastTimer;

  bool _loadingCats = true;
  bool _loadingEpg = false;
  int _epgLoaded = 0;
  String? _error;

  final _searchCtrl = TextEditingController();

  /// Layout tunables — match tvOS roughly. `pxPerMinute` ties cell
  /// width to programme duration so a 5-min interlude is visibly
  /// narrower than a 90-min film.
  static const double _bannerWidth = 260;
  static const double _rowHeight = 88;
  static const double _pxPerMinute = 4;
  static const double _cellMinWidth = 280;
  static const double _cellMaxWidth = 720;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // Decide initial filter from the route arg (when the user comes
    // from a specific category sidebar entry, land on that category;
    // otherwise default to favourites).
    final init = widget.initialCategoryId;
    if (init != null && init != '__favorites__' && init != '__watchlist__') {
      _filter = init;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final cats = await _repo.getLiveCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCats = false;
      });
      await _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeApiError(
            _repo.errorKey(e), AppLocalizations.of(context)!);
        _loadingCats = false;
      });
    }
  }

  /// Channels currently visible per the active filter. Computed on
  /// demand — keeps state surface small.
  List<Channel> _visibleChannels() {
    switch (_filter) {
      case '__favorites__':
        final favKeys = ref.read(favoritesProvider).keys;
        return _allChannels.where((c) => favKeys.contains(c.id)).toList();
      case '__all__':
        return _allChannels;
      default:
        return _allChannels
            .where((c) => c.categoryId == _filter)
            .toList();
    }
  }

  Future<void> _applyFilter() async {
    setState(() {
      _epgData = const <String, List<ParsedEpgProgram>>{};
      _epgLoaded = 0;
      _loadingEpg = true;
    });
    if (!_allChannelsLoaded) {
      try {
        final list = await _repo.getLiveStreams();
        if (!mounted) return;
        setState(() {
          _allChannels = list;
          _allChannelsLoaded = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = localizeApiError(
              _repo.errorKey(e), AppLocalizations.of(context)!);
          _loadingEpg = false;
        });
        return;
      }
    }
    final channels = _visibleChannels();
    if (channels.isEmpty) {
      setState(() => _loadingEpg = false);
      return;
    }
    await _loadEpgForChannels(channels);
  }

  Future<void> _loadEpgForChannels(List<Channel> channels) async {
    String dec(String s) {
      try {
        return utf8.decode(base64.decode(s));
      } catch (e, st) {
        AppLogger.warning(LogModule.epg,
            'Failed to decode base64 EPG string', error: e, stackTrace: st);
        return s;
      }
    }

    final dayStart = _selectedDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    final Map<String, List<ParsedEpgProgram>> epg = {};

    for (var i = 0; i < channels.length; i += 6) {
      final chunk = channels.skip(i).take(6);
      await Future.wait(chunk.map((ch) async {
        final sid = ch.id;
        try {
          Map<String, dynamic> data;
          try {
            data = await _repo.getFullDayEpg(sid);
          } catch (e, st) {
            AppLogger.warning(LogModule.epg,
                'Full-day EPG failed for $sid, falling back',
                error: e, stackTrace: st);
            data = await _repo.getShortEpg(sid, limit: 30);
          }
          final listings = data['epg_listings'] as List? ?? [];
          epg[sid] = listings
              .map((e) {
                final startTs = int.tryParse(
                    (e['start_timestamp'] ?? e['start'] ?? '').toString());
                final stopTs = int.tryParse(
                    (e['stop_timestamp'] ?? e['stop'] ?? '').toString());
                if (startTs == null || stopTs == null) return null;
                return ParsedEpgProgram(
                  title: dec(e['title']?.toString() ?? ''),
                  description: dec(e['description']?.toString() ?? ''),
                  start: DateTime.fromMillisecondsSinceEpoch(startTs * 1000),
                  end: DateTime.fromMillisecondsSinceEpoch(stopTs * 1000),
                  startUtc: DateTime.fromMillisecondsSinceEpoch(
                      startTs * 1000,
                      isUtc: true),
                  startServerLocal: e['start']?.toString() ?? '',
                );
              })
              .where((p) {
                if (p == null) return false;
                return p.start
                        .isAfter(dayStart.subtract(const Duration(hours: 1))) &&
                    p.start.isBefore(dayEnd);
              })
              .cast<ParsedEpgProgram>()
              .toList();
        } catch (e, st) {
          AppLogger.warning(LogModule.epg,
              'Failed to load EPG for channel $sid',
              error: e, stackTrace: st);
        }
      }));
      if (!mounted) return;
      setState(() {
        _epgData = Map.from(epg);
        _epgLoaded = (i + 6).clamp(0, channels.length);
      });
    }
    if (mounted) setState(() => _loadingEpg = false);
  }

  // ── Tap routing ──

  _ProgRuntime _runtime(ParsedEpgProgram p) {
    final now = DateTime.now();
    if (p.start.isAfter(now)) return _ProgRuntime.upcoming;
    if (p.end.isAfter(now)) return _ProgRuntime.current;
    return _ProgRuntime.past;
  }

  void _handleTap(Channel channel, ParsedEpgProgram prog) {
    switch (_runtime(prog)) {
      case _ProgRuntime.current:
        _playLive(channel);
        break;
      case _ProgRuntime.past:
        _playReplay(channel, prog);
        break;
      case _ProgRuntime.upcoming:
        _toggleReminder(channel, prog);
        break;
    }
  }

  void _playLive(Channel channel) {
    final url = _repo.getLiveStreamUrl(channel.id);
    Navigator.push(
      context,
      slideRoute(PlayerScreen(
        url: url,
        title: channel.name.strippingProviderTag,
        streamId: channel.id,
      )),
    );
  }

  void _playReplay(Channel channel, ParsedEpgProgram prog) {
    if (!channel.hasCatchup) {
      _showToast(AppLocalizations.of(context)!.replayNonDisponible);
      return;
    }
    final durationMin = prog.end.difference(prog.start).inMinutes;
    final startUtc = prog.startUtc ?? prog.start.toUtc();
    final url = prog.startServerLocal.isNotEmpty
        ? _repo.getTimeshiftUrlFromLocal(
            channel.id, prog.startServerLocal, durationMin)
        : _repo.getTimeshiftUrl(channel.id, startUtc, durationMin);
    Navigator.push(
      context,
      slideRoute(PlayerScreen(
        url: url,
        title:
            '${channel.name.strippingProviderTag} — ${prog.title} (${AppLocalizations.of(context)!.replay})',
        streamId: channel.id,
        isCatchup: true,
      )),
    );
  }

  Future<void> _toggleReminder(Channel channel, ParsedEpgProgram prog) async {
    final svc = EpgReminderService.instance;
    final startUtc = prog.startUtc ?? prog.start.toUtc();
    final has = svc.hasReminder(channel.id, startUtc);
    final l10n = AppLocalizations.of(context)!;
    if (has) {
      final id = '${channel.id}_${startUtc.millisecondsSinceEpoch}';
      await svc.remove(id);
      _showToast(l10n.rappelRetire);
    } else {
      await svc.add(EpgReminder(
        streamId: channel.id,
        channelName: channel.name.strippingProviderTag,
        programTitle: prog.title,
        startUtc: startUtc,
        durationMin: prog.end.difference(prog.start).inMinutes,
      ));
      _showToast(l10n.rappelPose(prog.title));
    }
    if (mounted) setState(() {});
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  // ── Day chip labels ──

  String _dayLabel(int offset) {
    if (offset == 0) return "Aujourd'hui";
    if (offset == 1) return 'Demain';
    if (offset == -1) return 'Hier';
    final date =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
            .add(Duration(days: offset));
    const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  int get _dayOffset {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _selectedDay.difference(today).inDays;
  }

  Future<void> _setDayOffset(int offset) async {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final newDay = today.add(Duration(days: offset));
    if (newDay == _selectedDay) return;
    setState(() {
      _selectedDay = newDay;
      _epgData = const <String, List<ParsedEpgProgram>>{};
      _epgLoaded = 0;
      _loadingEpg = true;
    });
    final channels = _visibleChannels();
    if (channels.isNotEmpty) {
      await _loadEpgForChannels(channels);
    } else {
      setState(() => _loadingEpg = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.guideTV,
          style: DSText.title2.copyWith(color: Colors.white),
        ),
        actions: <Widget>[
          if (_loadingEpg && _visibleChannels().isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DS.space.sm),
              child: Center(
                child: Text(
                  '$_epgLoaded/${_visibleChannels().length}',
                  style: DSText.caption.copyWith(color: DS.colour.textTertiary),
                ),
              ),
            ),
          IconButton(
            tooltip: _isSearchActive ? 'Fermer' : 'Rechercher',
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                }
              });
            },
          ),
          SizedBox(width: DS.space.xs),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              if (_isSearchActive) _buildSearchField(),
              _buildDayChips(),
              _buildFilterChips(),
              SizedBox(height: DS.space.sm),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: DS.space.xl,
              child: Center(child: _ToastChip(message: _toast!)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DS.padding.screenHorizontal,
        DS.space.xs,
        DS.padding.screenHorizontal,
        DS.space.xs,
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        cursorColor: AppColors.primaryBlue,
        style: DSText.body.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.titreChaine,
          hintStyle: DSText.body.copyWith(color: DS.colour.textTertiary),
          prefixIcon: Icon(Icons.search, color: DS.colour.textTertiary),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.10),
          contentPadding:
              EdgeInsets.symmetric(horizontal: DS.space.md, vertical: DS.space.sm),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DS.radius.pill),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildDayChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        itemCount: 15, // -7..+7
        separatorBuilder: (_, __) => SizedBox(width: DS.space.xxs),
        itemBuilder: (_, i) {
          final offset = i - 7;
          return _Chip(
            label: _dayLabel(offset),
            selected: offset == _dayOffset,
            onTap: () => _setDayOffset(offset),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        children: <Widget>[
          _Chip(
            label: AppLocalizations.of(context)!.favoris,
            icon: Icons.favorite,
            selected: _filter == '__favorites__',
            onTap: () {
              setState(() => _filter = '__favorites__');
              _applyFilter();
            },
          ),
          SizedBox(width: DS.space.xxs),
          _Chip(
            label: AppLocalizations.of(context)!.labelToutes,
            icon: Icons.live_tv,
            selected: _filter == '__all__',
            onTap: () {
              setState(() => _filter = '__all__');
              _applyFilter();
            },
          ),
          for (final c in _categories) ...<Widget>[
            SizedBox(width: DS.space.xxs),
            _Chip(
              label: c.categoryName,
              selected: _filter == c.categoryId,
              onTap: () {
                setState(() => _filter = c.categoryId);
                _applyFilter();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingCats) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(DS.space.lg),
          child: Text(
            _error!,
            style: DSText.body.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final channels = _visibleChannels();

    if (_isSearchActive && _searchQuery.isNotEmpty) {
      return _buildSearchResults(channels);
    }

    if (channels.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        DS.padding.screenHorizontal,
        DS.space.xs,
        DS.padding.screenHorizontal,
        DS.padding.contentBottom,
      ),
      itemCount: channels.length,
      separatorBuilder: (_, __) => SizedBox(height: DS.space.xs),
      itemBuilder: (_, i) => _channelRow(channels[i]),
    );
  }

  Widget _channelRow(Channel ch) {
    final progs = _epgData[ch.id];
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: <Widget>[
          _ChannelBanner(channel: ch),
          SizedBox(width: DS.space.sm),
          Expanded(child: _ProgramLane(
            channel: ch,
            programs: progs,
            rowHeight: _rowHeight,
            pxPerMinute: _pxPerMinute,
            cellMinWidth: _cellMinWidth,
            cellMaxWidth: _cellMaxWidth,
            runtimeOf: _runtime,
            hasReminderOf: (p) => EpgReminderService.instance
                .hasReminder(ch.id, p.startUtc ?? p.start.toUtc()),
            onTap: (p) => _handleTap(ch, p),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final String msg;
    switch (_filter) {
      case '__favorites__':
        msg = l10n.aucuneChaineFavorite;
        break;
      case '__all__':
        msg = l10n.aucuneChaineDisponible;
        break;
      default:
        msg = l10n.aucuneChaineCategorie;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.tv_off, size: 48, color: tc.textDisabled),
          SizedBox(height: DS.space.sm),
          Text(msg, style: DSText.body.copyWith(color: DS.colour.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Channel> channels) {
    final q = _searchQuery;
    final matches = <_SearchMatch>[];
    for (final ch in channels) {
      final chName = ch.name.strippingProviderTag.toLowerCase();
      final chMatch = chName.contains(q);
      final progs = _epgData[ch.id] ?? const <ParsedEpgProgram>[];
      for (final p in progs) {
        if (chMatch || p.title.toLowerCase().contains(q)) {
          matches.add(_SearchMatch(channel: ch, program: p));
        }
      }
    }
    matches.sort((a, b) => a.program.start.compareTo(b.program.start));

    if (matches.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          q.isEmpty ? l10n.tapezPourRechercher : l10n.aucunResultat,
          style: DSText.body.copyWith(color: DS.colour.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        DS.padding.screenHorizontal,
        DS.space.xs,
        DS.padding.screenHorizontal,
        DS.padding.contentBottom,
      ),
      itemCount: matches.length,
      separatorBuilder: (_, __) => SizedBox(height: DS.space.xs),
      itemBuilder: (_, i) => _SearchRow(
        match: matches[i],
        runtime: _runtime,
        onTap: () => _handleTap(matches[i].channel, matches[i].program),
      ),
    );
  }
}

enum _ProgRuntime { past, current, upcoming }

class _SearchMatch {
  const _SearchMatch({required this.channel, required this.program});
  final Channel channel;
  final ParsedEpgProgram program;
}

// ── Day / filter chip ──────────────────────────────────────────────

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color fg;
    if (_hovered) {
      fill = Colors.white;
      fg = Colors.black;
    } else if (widget.selected) {
      fill = AppColors.primaryBlue;
      fg = Colors.white;
    } else {
      fill = Colors.white.withValues(alpha: 0.10);
      fg = DS.colour.textSecondary;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          padding: EdgeInsets.symmetric(
            horizontal: DS.space.md,
            vertical: DS.space.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(DS.radius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 14, color: fg),
                SizedBox(width: DS.space.xxs),
              ],
              Text(
                widget.label,
                style: DSText.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Channel banner (left of every row) ─────────────────────────────

class _ChannelBanner extends StatelessWidget {
  const _ChannelBanner({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _EpgGridScreenState._bannerWidth,
      padding: EdgeInsets.symmetric(horizontal: DS.space.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(DS.radius.card),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(DS.radius.tag),
            child: SizedBox(
              width: 48,
              height: 48,
              child: channel.displayIcon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: channel.displayIcon,
                      cacheManager: AppCacheManager.instance,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          Container(color: AppColors.darkSurface),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.darkSurface,
                        child: Icon(Icons.tv, color: DS.colour.textTertiary),
                      ),
                    )
                  : Container(
                      color: AppColors.darkSurface,
                      child: Icon(Icons.tv, color: DS.colour.textTertiary),
                    ),
            ),
          ),
          SizedBox(width: DS.space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  channel.name.strippingProviderTag,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.bodyEmphasised.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    // `Channel.num` is typed `dynamic` and providers
                    // return it as either String or int — stringify
                    // before testing emptiness or rendering.
                    if (channel.num?.toString().isNotEmpty ?? false)
                      Text(
                        channel.num.toString(),
                        style: DSText.caption.copyWith(
                          color: DS.colour.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    if (channel.hasCatchup) ...<Widget>[
                      if (channel.num?.toString().isNotEmpty ?? false)
                        SizedBox(width: DS.space.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentWarm.withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(DS.radius.tag),
                        ),
                        child: const Text(
                          'REPLAY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Program lane (horizontal scroll inside a row) ──────────────────

class _ProgramLane extends StatelessWidget {
  const _ProgramLane({
    required this.channel,
    required this.programs,
    required this.rowHeight,
    required this.pxPerMinute,
    required this.cellMinWidth,
    required this.cellMaxWidth,
    required this.runtimeOf,
    required this.hasReminderOf,
    required this.onTap,
  });

  final Channel channel;
  final List<ParsedEpgProgram>? programs;
  final double rowHeight;
  final double pxPerMinute;
  final double cellMinWidth;
  final double cellMaxWidth;
  final _ProgRuntime Function(ParsedEpgProgram) runtimeOf;
  final bool Function(ParsedEpgProgram) hasReminderOf;
  final ValueChanged<ParsedEpgProgram> onTap;

  double _widthOf(ParsedEpgProgram p) {
    final mins = p.end.difference(p.start).inMinutes.clamp(15, 1000);
    final raw = mins * pxPerMinute;
    return raw.clamp(cellMinWidth, cellMaxWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final progs = programs;
    if (progs == null) {
      // Not loaded yet — skeleton.
      return Row(
        children: List<Widget>.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(right: DS.space.xs),
            child: Container(
              width: 360,
              height: rowHeight - 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(DS.radius.card),
              ),
            ),
          ),
        ),
      );
    }
    if (progs.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.space.md),
        child: Text(
          AppLocalizations.of(context)!.pasDeProgramme,
          style: DSText.caption.copyWith(color: DS.colour.textTertiary),
        ),
      );
    }
    // Find the first item to anchor scroll on — current programme on
    // today, otherwise first. We do this by computing an initial
    // offset and using a ScrollController with `initialScrollOffset`.
    int anchorIndex = 0;
    for (var i = 0; i < progs.length; i++) {
      if (runtimeOf(progs[i]) == _ProgRuntime.current) {
        anchorIndex = i;
        break;
      }
    }
    // Cheap initial offset: sum widths of preceding cells. Avoids a
    // ScrollViewBuilder + ScrollToIndex package dependency.
    double initial = 0;
    for (var i = 0; i < anchorIndex; i++) {
      initial += _widthOf(progs[i]) + 8;
    }
    final controller = ScrollController(initialScrollOffset: initial);

    return ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: progs.length,
      separatorBuilder: (_, __) => SizedBox(width: DS.space.xs),
      itemBuilder: (_, i) {
        final p = progs[i];
        return _ProgramCell(
          program: p,
          width: _widthOf(p),
          height: rowHeight - 8,
          runtime: runtimeOf(p),
          hasReminder: hasReminderOf(p),
          onTap: () => onTap(p),
        );
      },
    );
  }
}

// ── Program cell ───────────────────────────────────────────────────

class _ProgramCell extends StatefulWidget {
  const _ProgramCell({
    required this.program,
    required this.width,
    required this.height,
    required this.runtime,
    required this.hasReminder,
    required this.onTap,
  });

  final ParsedEpgProgram program;
  final double width;
  final double height;
  final _ProgRuntime runtime;
  final bool hasReminder;
  final VoidCallback onTap;

  @override
  State<_ProgramCell> createState() => _ProgramCellState();
}

class _ProgramCellState extends State<_ProgramCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.runtime == _ProgRuntime.current;
    final isPast = widget.runtime == _ProgRuntime.past;

    final Color bg;
    final Color border;
    if (_hovered) {
      bg = AppColors.primaryBlue.withValues(alpha: 0.65);
      border = AppColors.primaryBlue;
    } else if (isCurrent) {
      bg = AppColors.primaryBlue.withValues(alpha: 0.20);
      border = AppColors.primaryBlue.withValues(alpha: 0.85);
    } else if (isPast) {
      bg = Colors.white.withValues(alpha: 0.04);
      border = Colors.transparent;
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
      border = Colors.transparent;
    }

    final timeStr =
        '${_two(widget.program.start.hour)}:${_two(widget.program.start.minute)}';
    final endStr =
        '${_two(widget.program.end.hour)}:${_two(widget.program.end.minute)}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          width: widget.width,
          height: widget.height,
          padding: EdgeInsets.symmetric(
            horizontal: DS.space.sm,
            vertical: DS.space.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DS.radius.card),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (isCurrent)
                    Container(
                      margin: EdgeInsets.only(right: DS.space.xxs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarm,
                        borderRadius: BorderRadius.circular(DS.radius.tag),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.enCoursProg,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (widget.hasReminder)
                    Padding(
                      padding: EdgeInsets.only(right: DS.space.xxs),
                      child: Icon(
                        Icons.notifications_active,
                        size: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.program.title.isEmpty
                          ? 'Programme'
                          : widget.program.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DSText.bodyEmphasised.copyWith(
                        color: isPast
                            ? DS.colour.textTertiary
                            : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '$timeStr – $endStr',
                style: DSText.caption.copyWith(
                  color: isPast
                      ? DS.colour.textTertiary
                      : DS.colour.textSecondary,
                  fontSize: 11,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

// ── Search row ─────────────────────────────────────────────────────

class _SearchRow extends StatefulWidget {
  const _SearchRow({
    required this.match,
    required this.runtime,
    required this.onTap,
  });

  final _SearchMatch match;
  final _ProgRuntime Function(ParsedEpgProgram) runtime;
  final VoidCallback onTap;

  @override
  State<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends State<_SearchRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.match.channel;
    final p = widget.match.program;
    final state = widget.runtime(p);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          padding: EdgeInsets.symmetric(
            horizontal: DS.space.md,
            vertical: DS.space.sm,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DS.radius.card),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(DS.radius.tag),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: ch.displayIcon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ch.displayIcon,
                          cacheManager: AppCacheManager.instance,
                          fit: BoxFit.contain,
                          placeholder: (_, __) =>
                              Container(color: AppColors.darkSurface),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.darkSurface,
                            child:
                                Icon(Icons.tv, color: DS.colour.textTertiary),
                          ),
                        )
                      : Container(
                          color: AppColors.darkSurface,
                          child: Icon(Icons.tv, color: DS.colour.textTertiary),
                        ),
                ),
              ),
              SizedBox(width: DS.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSText.bodyEmphasised.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${_two(p.start.hour)}:${_two(p.start.minute)} · ${ch.name.strippingProviderTag}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSText.caption.copyWith(
                        color: DS.colour.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: DS.space.sm),
              _StateTag(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.state});
  final _ProgRuntime state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String label;
    final Color bg;
    final Color fg;
    switch (state) {
      case _ProgRuntime.current:
        label = l10n.enCoursProg;
        bg = AppColors.accentWarm;
        fg = Colors.white;
        break;
      case _ProgRuntime.past:
        label = l10n.statePasse;
        bg = Colors.white.withValues(alpha: 0.06);
        fg = DS.colour.textTertiary;
        break;
      case _ProgRuntime.upcoming:
        label = l10n.stateAVenir;
        bg = Colors.white.withValues(alpha: 0.06);
        fg = DS.colour.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DS.radius.tag),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ── Toast ──────────────────────────────────────────────────────────

class _ToastChip extends StatelessWidget {
  const _ToastChip({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DS.space.lg,
        vertical: DS.space.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(DS.radius.pill),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        style: DSText.body.copyWith(color: Colors.white),
      ),
    );
  }
}
