import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/models/channel.dart';
import 'package:unistream/providers/favorites_provider.dart';
import 'package:unistream/services/epg_reminder_service.dart';
import 'package:unistream/services/xtream_api.dart';
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
  List<Map<String, dynamic>> _programs = [];
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
      final data = await XtreamApi.getFullDayEpg(ch.id);
      final listings = data['epg_listings'] as List<dynamic>? ?? [];
      final parsed = <Map<String, dynamic>>[];
      for (final e in listings) {
        final m = e as Map<String, dynamic>;
        final startTs = int.tryParse(m['start_timestamp']?.toString() ?? '');
        final endTs = int.tryParse(m['stop_timestamp']?.toString() ?? '');
        if (startTs == null || endTs == null) continue;
        final start = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
        final end = DateTime.fromMillisecondsSinceEpoch(endTs * 1000);
        final title = _decodeBase64(m['title']?.toString() ?? '');
        final desc = _decodeBase64(m['description']?.toString() ?? '');
        parsed.add({
          'title': title,
          'description': desc,
          'start': start,
          'end': end,
          'start_server_local': m['start']?.toString() ?? '',
          'duration_min': end.difference(start).inMinutes,
        });
      }
      parsed.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
      if (mounted) setState(() { _programs = parsed; _loading = false; });
    } catch (e) {
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

  Map<String, dynamic>? get _currentProgram {
    final now = DateTime.now();
    for (final p in _programs) {
      if (now.isAfter(p['start'] as DateTime) && now.isBefore(p['end'] as DateTime)) {
        return p;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _upcomingPrograms {
    final now = DateTime.now();
    return _programs.where((p) => (p['start'] as DateTime).isAfter(now)).toList();
  }

  List<Map<String, dynamic>> get _replayablePrograms {
    if (!ch.hasCatchup) return [];
    final now = DateTime.now();
    return _programs
        .where((p) => (p['end'] as DateTime).isBefore(now))
        .toList()
        .reversed
        .toList();
  }

  void _playLive() {
    final url = XtreamApi.getLiveStreamUrl(ch.id);
    final current = _currentProgram;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: current != null ? '${ch.name} — ${current['title']}' : ch.name,
      streamId: ch.id,
      coverUrl: ch.displayIcon.isNotEmpty ? ch.displayIcon : null,
    )));
  }

  void _playReplay(Map<String, dynamic> prog) {
    final serverLocal = prog['start_server_local'] as String?;
    final durMin = prog['duration_min'] as int;
    final start = prog['start'] as DateTime;
    final url = (serverLocal != null && serverLocal.isNotEmpty)
        ? XtreamApi.getTimeshiftUrlFromLocal(ch.id, serverLocal, durMin)
        : XtreamApi.getTimeshiftUrl(ch.id, start.toUtc(), durMin);
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(context, slideRoute(PlayerScreen(
      url: url,
      title: '${ch.name} — ${prog['title']} (${l10n.replay})',
      streamId: ch.id,
      isCatchup: true,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final favKeys = ref.watch(favoritesProvider).keys;
    final favKey = 'live:${ch.id}';
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
                  Opacity(
                    opacity: 0.15,
                    child: CachedNetworkImage(
                      imageUrl: ch.displayIcon,
                      cacheManager: AppCacheManager.instance,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                // Gradient overlay
                Container(
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
                ),
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
                  ref.read(favoritesProvider.notifier).toggle(favKey, {
                    'stream_id': ch.streamId,
                    'name': ch.name,
                    'stream_icon': ch.streamIcon,
                    '_mode': 'live',
                  });
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

  Widget _buildProgramTile(Map<String, dynamic> prog, AppThemeColors tc, {
    bool isCurrent = false,
    bool isFuture = false,
    bool isReplay = false,
  }) {
    final start = prog['start'] as DateTime;
    final end = prog['end'] as DateTime;
    final title = prog['title'] as String? ?? '';
    final desc = prog['description'] as String? ?? '';
    final durMin = prog['duration_min'] as int;
    final timeStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        ' - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    // Progress for current program
    double? progress;
    if (isCurrent) {
      final total = end.difference(start).inSeconds;
      final elapsed = DateTime.now().difference(start).inSeconds;
      if (total > 0) progress = (elapsed / total).clamp(0.0, 1.0);
    }

    // Reminder check for future programs
    final hasReminder = isFuture &&
        EpgReminderService.instance.hasReminder(ch.id, start.toUtc());

    return Padding(
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
                  Text(timeStr, style: TextStyle(fontSize: 11, color: tc.textDisabled,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text('${durMin}min', style: TextStyle(fontSize: 10, color: tc.textDisabled)),
                  const Spacer(),
                  if (isReplay)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('REPLAY', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red, borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('LIVE', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  if (hasReminder)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.notifications_active, size: 14, color: Colors.amber),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 13, color: tc.textPrimary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(desc, style: TextStyle(fontSize: 11, color: tc.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: tc.divider,
                      color: Colors.red,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleReminder(Map<String, dynamic> prog) {
    final start = prog['start'] as DateTime;
    final svc = EpgReminderService.instance;
    final has = svc.hasReminder(ch.id, start.toUtc());
    if (has) {
      svc.remove('${ch.id}_${start.toUtc().millisecondsSinceEpoch}');
    } else {
      svc.add(EpgReminder(
        streamId: ch.id,
        channelName: ch.name,
        programTitle: prog['title'] ?? '',
        startUtc: start.toUtc(),
        durationMin: prog['duration_min'] as int,
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
