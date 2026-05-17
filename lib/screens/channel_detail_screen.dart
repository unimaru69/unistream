import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/models/favorite_item.dart';
import 'package:unistream/models/parsed_epg_program.dart';
import 'package:unistream/providers/favorites_provider.dart';
import 'package:unistream/services/epg_reminder_service.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/core/logger.dart';
import 'package:unistream/utils/routes.dart';
import 'package:unistream/widgets/skeleton_list.dart';
import 'player/player_screen.dart';

/// Full-page detail screen for a live TV channel.
/// Shows channel info, current/next programs, and catch-up replay list.
class ChannelDetailScreen extends ConsumerStatefulWidget {
  final Channel channel;
  const ChannelDetailScreen({super.key, required this.channel});

  @override
  ConsumerState<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);
  List<ParsedEpgProgram> _programs = [];
  bool _loading = true;
  String? _error;

  Channel get ch => widget.channel;

  @override
  void initState() {
    super.initState();
    _loadEpg();
  }

  Future<void> _loadEpg() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getFullDayEpg(ch.id);
      final listings = data['epg_listings'] as List<dynamic>? ?? [];
      final parsed = <ParsedEpgProgram>[];
      for (final e in listings) {
        final m = e as Map<String, dynamic>;
        final startTs = int.tryParse(m['start_timestamp']?.toString() ?? '');
        final endTs = int.tryParse(m['stop_timestamp']?.toString() ?? '');
        if (startTs == null || endTs == null) continue;
        final start = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
        final end = DateTime.fromMillisecondsSinceEpoch(endTs * 1000);
        parsed.add(ParsedEpgProgram(
          title: _decodeBase64(m['title']?.toString() ?? ''),
          description: _decodeBase64(m['description']?.toString() ?? ''),
          start: start,
          end: end,
          startServerLocal: m['start']?.toString() ?? '',
        ));
      }
      parsed.sort((a, b) => a.start.compareTo(b.start));
      if (mounted) setState(() { _programs = parsed; _loading = false; });
    } catch (e, st) {
      AppLogger.warning('epg', 'Failed to load EPG for channel', error: e, stackTrace: st);
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _decodeBase64(String input) {
    if (input.isEmpty) return '';
    try {
      return String.fromCharCodes(
          const Base64Decoder().convert(input));
    } catch (_) {
      return input;
    }
  }

  ParsedEpgProgram? get _currentProgram {
    for (final p in _programs) {
      if (p.isCurrent) return p;
    }
    return null;
  }

  List<ParsedEpgProgram> get _upcomingPrograms {
    return _programs.where((p) => p.isFuture).toList();
  }

  List<ParsedEpgProgram> get _replayablePrograms {
    if (!ch.hasCatchup) return [];
    return _programs
        .where((p) => p.isPast)
        .toList()
        .reversed
        .toList();
  }

  void _playLive() {
    final url = _repo.getLiveStreamUrl(ch.id);
    final current = _currentProgram;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: current != null ? '${ch.name} — ${current.title}' : ch.name,
      streamId: ch.id,
      coverUrl: ch.displayIcon.isNotEmpty ? ch.displayIcon : null,
    )));
  }

  void _playReplay(ParsedEpgProgram prog) {
    final url = (prog.startServerLocal.isNotEmpty)
        ? _repo.getTimeshiftUrlFromLocal(ch.id, prog.startServerLocal, prog.durationMin)
        : _repo.getTimeshiftUrl(ch.id, prog.start.toUtc(), prog.durationMin);
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: '${ch.name} — ${prog.title} (${l10n.replay})',
      streamId: ch.id,
      isCatchup: true,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final favKeys = ref.watch(favoritesProvider).keys;
    // Bare channel id — aligns with tvOS FavoriteItem.from(channel:)
    // which stores `key: channel.streamId`. The `mode: "live"` field
    // on the JSON keeps the type discriminator.
    final favKey = ch.id.toString();
    final isFav = favKeys.contains(favKey);

    return Scaffold(
      backgroundColor: tc.surfaceAlt,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
          onRefresh: _loadEpg,
          child: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: tc.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(ch.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              background: Stack(fit: StackFit.expand, children: [
                // Blurred background logo (decorative)
                if (ch.displayIcon.isNotEmpty)
                  ExcludeSemantics(child: Opacity(
                    opacity: 0.15,
                    child: CachedNetworkImage(
                      imageUrl: ch.displayIcon,
                      cacheManager: AppCacheManager.instance,
                      fit: BoxFit.cover,
                      // Backdrop wash at 15 % opacity — a 512 px
                      // decode is more than enough behind the
                      // gradient and centered sharp logo.
                      memCacheWidth: 512,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  )),
                // Gradient overlay
                ExcludeSemantics(child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryBlue.withValues(alpha: 0.25),
                        tc.surface.withValues(alpha: 0.7),
                        tc.surface,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                )),
                // Centered sharp logo
                Center(
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: tc.logoBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ch.displayIcon.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ch.displayIcon,
                            cacheManager: AppCacheManager.instance,
                            fit: BoxFit.contain,
                            memCacheWidth: (88 * MediaQuery.devicePixelRatioOf(context)).round(),
                            memCacheHeight: (88 * MediaQuery.devicePixelRatioOf(context)).round(),
                            errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 40),
                          )
                        : const Icon(Icons.tv, size: 40),
                  ),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: Icon(isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : null),
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(favKey, FavoriteItem(
                    key: favKey, name: ch.name, cover: ch.displayIcon,
                    mode: 'live', streamId: ch.streamId.toString(),
                    streamIcon: ch.streamIcon,
                  ));
                },
                tooltip: l10n.favoris,
              ),
            ],
          ),

          // ── Play live button ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _playLive,
                icon: const Icon(Icons.play_arrow),
                label: Text(ch.name),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),

          // ── Info chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, children: [
                if (ch.categoryName != null && ch.categoryName!.isNotEmpty)
                  Chip(label: Text(ch.categoryName!, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact),
                if (ch.hasCatchup)
                  Chip(
                    avatar: const Icon(Icons.replay, size: 14),
                    label: Text('Catch-up ${ch.archiveDays}j', style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.accentGreen.withValues(alpha: 0.2),
                    visualDensity: VisualDensity.compact,
                  ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── EPG content ──
          if (_loading)
            const SliverFillRemaining(child: SkeletonList(count: 6))
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.erreur, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _loadEpg, child: Text(l10n.reessayer)),
                ])),
              ),
            )
          else ...[
            // ── Current program ──
            if (_currentProgram != null)
              _buildSection(
                tc,
                icon: Icons.fiber_manual_record,
                iconColor: Colors.red,
                title: 'EN DIRECT',
                child: _buildProgramTile(_currentProgram!, tc, isCurrent: true),
              ),

            // ── Upcoming ──
            if (_upcomingPrograms.isNotEmpty)
              _buildSection(
                tc,
                icon: Icons.schedule,
                iconColor: AppColors.primaryBlue,
                title: l10n.aVenir,
                child: Column(
                  children: _upcomingPrograms.take(5).map((p) =>
                      _buildProgramTile(p, tc, isFuture: true)).toList(),
                ),
              ),

            // ── Catch-up replays ──
            if (_replayablePrograms.isNotEmpty)
              _buildSection(
                tc,
                icon: Icons.replay,
                iconColor: AppColors.accentGreen,
                title: l10n.replay,
                child: Column(
                  children: _replayablePrograms.take(10).map((p) =>
                      _buildProgramTile(p, tc, isReplay: true)).toList(),
                ),
              ),

            // ── Empty EPG ──
            if (_programs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.aucunResultat,
                      style: TextStyle(color: tc.textDisabled))),
                ),
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSection(AppThemeColors tc, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: tc.textPrimary)),
            ]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProgramTile(ParsedEpgProgram prog, AppThemeColors tc, {
    bool isCurrent = false,
    bool isFuture = false,
    bool isReplay = false,
  }) {
    // Progress for current program
    double? progress;
    if (isCurrent) {
      final total = prog.end.difference(prog.start).inSeconds;
      final elapsed = DateTime.now().difference(prog.start).inSeconds;
      if (total > 0) progress = (elapsed / total).clamp(0.0, 1.0);
    }

    // Reminder check for future programs
    final hasReminder = isFuture &&
        EpgReminderService.instance.hasReminder(ch.id, prog.start.toUtc());

    return Semantics(
      button: isReplay || isCurrent,
      label: [
        prog.title,
        prog.timeRange,
        '${prog.durationMin} min',
        if (isCurrent) 'en direct',
        if (isReplay) 'replay disponible',
        if (hasReminder) 'rappel actif',
      ].join(', '),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: isCurrent
              ? AppColors.primaryBlue.withValues(alpha: 0.12)
              : isReplay
              ? AppColors.accentGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isReplay ? () => _playReplay(prog) : isCurrent ? _playLive : null,
            onLongPress: isFuture ? () => _toggleReminder(prog) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ExcludeSemantics(child: Text(prog.timeRange, style: TextStyle(fontSize: 11, color: tc.textDisabled,
                        fontWeight: FontWeight.w500))),
                    const SizedBox(width: 8),
                    ExcludeSemantics(child: Text('${prog.durationMin}min', style: TextStyle(fontSize: 10, color: tc.textDisabled))),
                    const Spacer(),
                    if (isReplay)
                      ExcludeSemantics(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('REPLAY', style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                      )),
                    if (isCurrent)
                      ExcludeSemantics(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red, borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LIVE', style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                      )),
                    if (hasReminder)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.notifications_active, size: 14, color: Colors.amber),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  ExcludeSemantics(child: Text(prog.title, style: TextStyle(fontSize: 13, color: tc.textPrimary,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal))),
                  if (prog.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ExcludeSemantics(child: Text(prog.description, style: TextStyle(fontSize: 11, color: tc.textSecondary),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ExcludeSemantics(child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: tc.divider,
                        color: Colors.red,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      )),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleReminder(ParsedEpgProgram prog) {
    final svc = EpgReminderService.instance;
    final has = svc.hasReminder(ch.id, prog.start.toUtc());
    if (has) {
      svc.remove('${ch.id}_${prog.start.toUtc().millisecondsSinceEpoch}');
    } else {
      svc.add(EpgReminder(
        streamId: ch.id,
        channelName: ch.name,
        programTitle: prog.title,
        startUtc: prog.start.toUtc(),
        durationMin: prog.durationMin,
      ));
    }
    setState(() {});
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(has ? l10n.meRappeler : l10n.rappelActif),
      duration: const Duration(seconds: 2),
    ));
  }
}
