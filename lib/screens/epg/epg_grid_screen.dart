import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/skeleton_list.dart';
import 'package:unistream/core/cache_config.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/category.dart' as cat;
import '../../models/channel.dart';
import '../../providers/favorites_provider.dart';
import '../../services/xtream_api.dart';
import '../../services/epg_reminder_service.dart';
import '../../utils/api_error_localizer.dart';
import '../../utils/routes.dart';
import '../player/player_screen.dart';
import 'widgets/epg_day_navigator.dart';

// ── EPG Grid Screen ──
class EpgGridScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  const EpgGridScreen({super.key, this.initialCategoryId});
  @override
  ConsumerState<EpgGridScreen> createState() => _EpgGridScreenState();
}

class _EpgGridScreenState extends ConsumerState<EpgGridScreen> {
  // Categories
  List<cat.Category> _categories = [];
  String? _selectedCatId;
  bool _loadingCats = true;

  // Channels for selected category
  List<Channel> _channels = [];
  bool _loadingChannels = false;

  // EPG data: channelId → programs
  Map<String, List<Map<String, dynamic>>> _epgData = {};
  bool _loadingEpg = false;
  int _epgLoaded = 0; // progress counter

  String? _error;

  // Search / filter
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Category sidebar resize
  double _catSidebarWidth = 200;
  static const double _catSidebarMin = 120;
  static const double _catSidebarMax = 400;

  // Timeline
  late DateTime _dayStart;
  final double _hourWidth = 300;
  final double _channelColWidth = 180;
  final double _rowHeight = 50;

  // Scroll sync: two independent controllers synced manually
  final _headerHScroll = ScrollController();
  final _gridHScroll   = ScrollController();
  final _channelVScroll = ScrollController();
  final _gridVScroll    = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _dayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _loadCategories();

    // Sync horizontal scroll: header ↔ grid
    _headerHScroll.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_gridHScroll.hasClients) _gridHScroll.jumpTo(_headerHScroll.offset);
      _syncingH = false;
    });
    _gridHScroll.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_headerHScroll.hasClients) _headerHScroll.jumpTo(_gridHScroll.offset);
      _syncingH = false;
    });

    // Sync vertical scroll: channel col ↔ grid
    _channelVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_gridVScroll.hasClients) _gridVScroll.jumpTo(_channelVScroll.offset);
      _syncingV = false;
    });
    _gridVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_channelVScroll.hasClients) _channelVScroll.jumpTo(_gridVScroll.offset);
      _syncingV = false;
    });
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _gridHScroll.dispose();
    _channelVScroll.dispose();
    _gridVScroll.dispose();
    super.dispose();
  }

  Future<void> _selectFavorites() async {
    setState(() {
      _selectedCatId = '__favorites__';
      _loadingChannels = true;
      _channels = [];
      _epgData = {};
      _epgLoaded = 0;
    });

    try {
      final streams = await XtreamApi.getLiveStreamsTyped();
      final channels = streams
          .where((ch) => ref.read(favoritesProvider).keys.contains(ch.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loadingChannels = false;
        _loadingEpg = true;
      });

      // Load EPG for favorite channels
      final Map<String, List<Map<String, dynamic>>> epg = {};
      for (var i = 0; i < channels.length; i += 6) {
        final chunk = channels.skip(i).take(6);
        await Future.wait(chunk.map((ch) async {
          final sid = ch.id;
          try {
            Map<String, dynamic> data;
            try { data = await XtreamApi.getFullDayEpg(sid); }
            catch (e, st) { AppLogger.warning(LogModule.epg, 'Full-day EPG failed for $sid, falling back to short EPG', error: e, stackTrace: st); data = await XtreamApi.getShortEpg(sid, limit: 30); }
            final listings = data['epg_listings'] as List? ?? [];
            final today = _dayStart;
            final tomorrow = _dayStart.add(const Duration(days: 1));
            epg[sid] = listings.map((e) {
              String dec(String s) { try { return utf8.decode(base64.decode(s)); } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG string', error: e, stackTrace: st); return s; } }
              final startTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
              final stopTs  = int.tryParse((e['stop_timestamp']  ?? e['stop']  ?? '').toString());
              final rawStartStr = e['start']?.toString();
              return {
                'title': dec(e['title']?.toString() ?? ''),
                'description': dec(e['description']?.toString() ?? ''),
                'start': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000) : null,
                'end':   stopTs  != null ? DateTime.fromMillisecondsSinceEpoch(stopTs  * 1000) : null,
                'start_utc': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000, isUtc: true) : null,
                'start_server_local': rawStartStr,
              };
            }).where((p) {
              if (p['start'] == null || p['end'] == null) return false;
              final s = p['start'] as DateTime;
              return s.isAfter(today.subtract(const Duration(hours: 1))) && s.isBefore(tomorrow);
            }).toList();
          } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to load EPG for channel $sid', error: e, stackTrace: st); }
        }));
        if (mounted) setState(() {
          _epgData = Map.from(epg);
          _epgLoaded = (i + 6).clamp(0, channels.length);
        });
      }

      if (mounted) setState(() => _loadingEpg = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = DateTime.now();
        final offset = now.difference(_dayStart).inMinutes * _hourWidth / 60 - 200;
        if (_gridHScroll.hasClients) {
          final clamped = offset.clamp(0.0, _gridHScroll.position.maxScrollExtent);
          _gridHScroll.jumpTo(clamped);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _loadingChannels = false; });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await XtreamApi.getLiveCategoriesTyped();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCats = false;
      });
      // Auto-select initial category or first one
      if (cats.isNotEmpty) {
        final initId = widget.initialCategoryId;
        final match = initId != null && initId != '__favorites__' && initId != '__watchlist__'
            ? cats.firstWhere((c) => c.categoryId == initId, orElse: () => cats.first)
            : cats.first;
        _selectCategory(match.categoryId);
      }
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _loadingCats = false; });
    }
  }

  Future<void> _selectCategory(String catId) async {
    setState(() {
      _selectedCatId = catId;
      _loadingChannels = true;
      _channels = [];
      _epgData = {};
      _epgLoaded = 0;
    });

    try {
      final channels = await XtreamApi.getLiveStreamsTyped(catId);
      // Sort favorites first
      if (ref.read(favoritesProvider).keys.isNotEmpty) {
        channels.sort((a, b) {
          final aFav = ref.read(favoritesProvider).keys.contains(a.id) ? 0 : 1;
          final bFav = ref.read(favoritesProvider).keys.contains(b.id) ? 0 : 1;
          return aFav.compareTo(bFav);
        });
      }
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loadingChannels = false;
        _loadingEpg = true;
      });

      // Load full-day EPG in batches of 6 (heavier payload than short EPG)
      final Map<String, List<Map<String, dynamic>>> epg = {};
      for (var i = 0; i < channels.length; i += 6) {
        final chunk = channels.skip(i).take(6);
        await Future.wait(chunk.map((ch) async {
          final sid = ch.id;
          try {
            // Try full-day EPG first, fallback to short EPG
            Map<String, dynamic> data;
            try {
              data = await XtreamApi.getFullDayEpg(sid);
            } catch (e, st) {
              AppLogger.warning(LogModule.epg, 'Full-day EPG failed for $sid, falling back to short EPG', error: e, stackTrace: st);
              data = await XtreamApi.getShortEpg(sid, limit: 30);
            }
            final listings = data['epg_listings'] as List? ?? [];
            final today = _dayStart;
            final tomorrow = _dayStart.add(const Duration(days: 1));
            epg[sid] = listings.map((e) {
              String dec(String s) { try { return utf8.decode(base64.decode(s)); } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG string', error: e, stackTrace: st); return s; } }
              final startTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
              final stopTs  = int.tryParse((e['stop_timestamp']  ?? e['stop']  ?? '').toString());
              // Store raw 'start' string from API — this is in server local time
              // e.g. "2026-03-30 08:30:00" — used directly for timeshift URL (DST-safe)
              final rawStartStr = e['start']?.toString();
              return {
                'title': dec(e['title']?.toString() ?? ''),
                'description': dec(e['description']?.toString() ?? ''),
                'start': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000) : null,
                'end':   stopTs  != null ? DateTime.fromMillisecondsSinceEpoch(stopTs  * 1000) : null,
                'start_utc': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000, isUtc: true) : null,
                'start_server_local': rawStartStr,
              };
            }).where((p) {
              if (p['start'] == null || p['end'] == null) return false;
              final s = p['start'] as DateTime;
              // Keep only today's programs
              return s.isAfter(today.subtract(const Duration(hours: 1))) && s.isBefore(tomorrow);
            }).toList();
          } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to load EPG for channel $sid', error: e, stackTrace: st); }
        }));
        if (mounted) setState(() {
          _epgData = Map.from(epg);
          _epgLoaded = (i + 6).clamp(0, channels.length);
        });
      }

      if (mounted) setState(() => _loadingEpg = false);

      // Scroll to current time
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = DateTime.now();
        final offset = now.difference(_dayStart).inMinutes * _hourWidth / 60 - 200;
        if (_gridHScroll.hasClients) {
          final clamped = offset.clamp(0.0, _gridHScroll.position.maxScrollExtent);
          _gridHScroll.jumpTo(clamped);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _error = localizeApiError(XtreamApi.errorKey(e), AppLocalizations.of(context)!); _loadingChannels = false; });
    }
  }

  List<Channel> get _filteredChannels {
    if (_searchQuery.isEmpty) return _channels;
    return _channels.where((ch) {
      // Match channel name
      if (ch.name.toLowerCase().contains(_searchQuery)) return true;
      // Also match program titles for this channel
      final progs = _epgData[ch.id] ?? [];
      return progs.any((p) =>
          (p['title'] as String? ?? '').toLowerCase().contains(_searchQuery));
    }).toList();
  }

  // ── French date formatting ──
  static const _frDays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _frMonths = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  String _fmtDayFr(DateTime d) {
    return '${_frDays[d.weekday - 1]} ${d.day} ${_frMonths[d.month - 1]} ${d.year}';
  }

  /// Max archive days across loaded channels (at least 3).
  int get _maxArchiveDays {
    if (_channels.isEmpty) return 3;
    final max = _channels.fold<int>(0, (prev, ch) => ch.archiveDays > prev ? ch.archiveDays : prev);
    return max.clamp(3, 14);
  }

  bool get _canGoPrev {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _dayStart.isAfter(today.subtract(Duration(days: _maxArchiveDays)));
  }

  bool get _canGoNext {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _dayStart.isBefore(today.add(const Duration(days: 3)));
  }

  void _changeDay(int delta) {
    final newDay = _dayStart.add(Duration(days: delta));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (newDay.isBefore(today.subtract(Duration(days: _maxArchiveDays))) ||
        newDay.isAfter(today.add(const Duration(days: 3)))) return;

    setState(() {
      _dayStart = newDay;
      _epgData = {};
      _epgLoaded = 0;
      _loadingEpg = true;
    });

    // Reload EPG for the new day
    if (_selectedCatId == '__favorites__') {
      _reloadEpgForChannels(_channels);
    } else if (_selectedCatId != null) {
      _reloadEpgForChannels(_channels);
    }
  }

  Future<void> _reloadEpgForChannels(List<Channel> channels) async {
    final dayEnd = _dayStart.add(const Duration(days: 1));
    final Map<String, List<Map<String, dynamic>>> epg = {};

    for (var i = 0; i < channels.length; i += 6) {
      final chunk = channels.skip(i).take(6);
      await Future.wait(chunk.map((ch) async {
        final sid = ch.id;
        try {
          Map<String, dynamic> data;
          try { data = await XtreamApi.getFullDayEpg(sid); }
          catch (e, st) { AppLogger.warning(LogModule.epg, 'Full-day EPG reload failed for $sid, falling back to short EPG', error: e, stackTrace: st); data = await XtreamApi.getShortEpg(sid, limit: 30); }
          final listings = data['epg_listings'] as List? ?? [];
          epg[sid] = listings.map((e) {
            String dec(String s) { try { return utf8.decode(base64.decode(s)); } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG string', error: e, stackTrace: st); return s; } }
            final startTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
            final stopTs  = int.tryParse((e['stop_timestamp']  ?? e['stop']  ?? '').toString());
            final rawStartStr = e['start']?.toString();
            return {
              'title': dec(e['title']?.toString() ?? ''),
              'description': dec(e['description']?.toString() ?? ''),
              'start': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000) : null,
              'end':   stopTs  != null ? DateTime.fromMillisecondsSinceEpoch(stopTs  * 1000) : null,
              'start_utc': startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000, isUtc: true) : null,
              'start_server_local': rawStartStr,
            };
          }).where((p) {
            if (p['start'] == null || p['end'] == null) return false;
            final s = p['start'] as DateTime;
            return s.isAfter(_dayStart.subtract(const Duration(hours: 1))) && s.isBefore(dayEnd);
          }).toList();
        } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to reload EPG for channel $sid', error: e, stackTrace: st); }
      }));
      if (mounted) setState(() {
        _epgData = Map.from(epg);
        _epgLoaded = (i + 6).clamp(0, channels.length);
      });
    }

    if (mounted) setState(() => _loadingEpg = false);

    // Scroll to appropriate position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final isToday = _dayStart.year == today.year && _dayStart.month == today.month && _dayStart.day == today.day;
      final double offset;
      if (isToday) {
        offset = DateTime.now().difference(_dayStart).inMinutes * _hourWidth / 60 - 200;
      } else {
        offset = 0; // beginning of day for non-today
      }
      if (_gridHScroll.hasClients) {
        final clamped = offset.clamp(0.0, _gridHScroll.position.maxScrollExtent);
        _gridHScroll.jumpTo(clamped);
      }
    });
  }

  String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}:00';

  Widget _buildTimelineHeader() {
    final tc = AppThemeColors.of(context);
    return SizedBox(
      width: _hourWidth * 24,
      height: 30,
      child: Stack(children: [
        for (var h = 0; h < 24; h++)
          Positioned(
            left: h * _hourWidth,
            top: 0, bottom: 0,
            child: Container(
              width: _hourWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.darkText,
                border: Border(left: BorderSide(color: tc.divider, width: 0.5)),
              ),
              child: Text(_fmtHour(h), style: TextStyle(fontSize: 10, color: tc.textTertiary)),
            ),
          ),
        // Current time marker
        Positioned(
          left: DateTime.now().difference(_dayStart).inMinutes * _hourWidth / 60,
          top: 0, bottom: 0,
          child: Container(width: 2, color: Colors.redAccent),
        ),
      ]),
    );
  }

  Widget _buildChannelRow(int i, List<Channel> channels) {
    final tc = AppThemeColors.of(context);
    final ch = channels[i];
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: i.isEven ? tc.surface : tc.surfaceAlt,
        border: Border(bottom: BorderSide(color: tc.inputFill, width: 0.5)),
      ),
      child: Row(children: [
        if (ch.displayIcon.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 28, height: 28,
              color: const Color(0xFF1E1E2E),
              child: CachedNetworkImage(
                cacheManager: AppCacheManager.instance,
                imageUrl: ch.displayIcon,
                width: 28, height: 28, fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const SizedBox(width: 28, height: 28),
                errorWidget: (_, __, ___) => Icon(Icons.tv, size: 16, color: tc.borderColor),
              ),
            ),
          )
        else
          Icon(Icons.tv, size: 16, color: tc.borderColor),
        const SizedBox(width: 6),
        Expanded(child: Text(
          ch.name,
          style: TextStyle(fontSize: 11, color: tc.textSecondary),
          overflow: TextOverflow.ellipsis,
        )),
        if (ch.hasCatchup)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3)),
            child: Text('${ch.archiveDays}j',
                style: TextStyle(fontSize: 9, color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  void _showProgramDetail(Map<String, dynamic> prog, DateTime start, DateTime end, String desc, {Channel? channel}) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isFuture = DateTime.now().isBefore(start);
    final reminderSvc = EpgReminderService.instance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final nowHasReminder = channel != null && isFuture
              && reminderSvc.hasReminder(channel.id, start.toUtc());
          return AlertDialog(
            backgroundColor: AppColors.darkText,
            title: Text(prog['title'] ?? '', style: TextStyle(color: tc.textPrimary, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}'
                    ' — ${end.hour.toString().padLeft(2,'0')}:${end.minute.toString().padLeft(2,'0')}',
                    style: TextStyle(color: tc.textSecondary, fontSize: 13),
                  ),
                  if (channel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(channel.name,
                          style: TextStyle(color: tc.textDisabled, fontSize: 12)),
                    ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(desc, style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              if (channel != null && isFuture)
                nowHasReminder
                    ? TextButton.icon(
                        icon: const Icon(Icons.notifications_active, size: 16, color: Colors.amber),
                        label: Text(l10n.rappelActif, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                        onPressed: () {
                          final id = '${channel.id}_${start.toUtc().millisecondsSinceEpoch}';
                          reminderSvc.remove(id);
                          setDialogState(() {});
                        },
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.notifications_none, size: 16),
                        label: Text(l10n.meRappeler, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          reminderSvc.add(EpgReminder(
                            streamId: channel.id,
                            channelName: channel.name,
                            programTitle: prog['title'] ?? '',
                            startUtc: start.toUtc(),
                            durationMin: end.difference(start).inMinutes,
                          ));
                          setDialogState(() {});
                        },
                      ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.fermer),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgramRow(int i, List<Channel> channels) {
    final tc = AppThemeColors.of(context);
    final ch = channels[i];
    final sid = ch.id;
    final progs = _epgData[sid] ?? [];
    final now = DateTime.now();
    final totalWidth = _hourWidth * 24;
    final hasCatchup = ch.hasCatchup;

    // Sort programs by start time to build a linear Row
    final sorted = List<Map<String, dynamic>>.from(progs)
      ..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

    // Build cells: [gap, program, gap, program, ...] as SizedBox widgets
    final cells = <Widget>[];
    double cursorX = 0;

    for (final prog in sorted) {
      final start = prog['start'] as DateTime;
      final end   = prog['end'] as DateTime;
      var leftPx  = start.difference(_dayStart).inMinutes * _hourWidth / 60;
      var widthPx = end.difference(start).inMinutes * _hourWidth / 60;

      // Clamp to totalWidth bounds
      if (leftPx < 0) { widthPx += leftPx; leftPx = 0; }
      if (leftPx + widthPx > totalWidth) widthPx = totalWidth - leftPx;
      if (widthPx <= 2) continue;

      // Skip if this program starts before our cursor (overlap from data)
      if (leftPx < cursorX) {
        final overlap = cursorX - leftPx;
        leftPx = cursorX;
        widthPx -= overlap;
        if (widthPx <= 2) continue;
      }

      // Insert gap before this program
      if (leftPx > cursorX) {
        cells.add(SizedBox(width: leftPx - cursorX));
      }

      // Build the program cell
      final isCurrent = now.isAfter(start) && now.isBefore(end);
      final isPast    = now.isAfter(end);
      final canReplay = isPast && hasCatchup;
      final durMin    = end.difference(start).inMinutes;
      final isFuture  = !isPast && !isCurrent;
      final hasReminder = isFuture && EpgReminderService.instance.hasReminder(sid, start.toUtc());
      final title     = '${canReplay ? '↻ ' : ''}${prog['title'] ?? ''}';

      final matchesSearch = _searchQuery.isNotEmpty &&
          (prog['title'] as String? ?? '').toLowerCase().contains(_searchQuery);
      final cellColor = matchesSearch
          ? Colors.amber.withValues(alpha: 0.35)
          : isCurrent
          ? AppColors.primaryBlue.withValues(alpha: 0.4)
          : canReplay
          ? AppColors.accentGreen.withValues(alpha: 0.25)
          : isPast
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.08);
      final cellBorder = isCurrent
          ? Border.all(color: AppColors.primaryBlue, width: 1)
          : canReplay
          ? Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4), width: 0.5)
          : null;
      final textColor = isCurrent ? tc.textPrimary
          : canReplay ? tc.textSecondary
          : isPast ? tc.borderColor
          : tc.textSecondary;

      final cellWidth = widthPx - 1; // 1px visual gap

      final desc = (prog['description'] ?? '') as String;
      final descTrunc = desc.length > 100 ? '${desc.substring(0, 100)}…' : desc;

      cells.add(SizedBox(
        width: cellWidth > 0 ? cellWidth : 0,
        child: Tooltip(
          message: '${prog['title']}\n'
              '${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}'
              ' — ${end.hour.toString().padLeft(2,'0')}:${end.minute.toString().padLeft(2,'0')}'
              '${descTrunc.isNotEmpty ? '\n$descTrunc' : ''}'
              '${canReplay ? '\n▶ ${AppLocalizations.of(context)!.cliquerPourRevoir}' : ''}',
          child: GestureDetector(
            onTap: () {
              if (canReplay) {
                final serverLocal = prog['start_server_local'] as String?;
                final url = (serverLocal != null && serverLocal.isNotEmpty)
                    ? XtreamApi.getTimeshiftUrlFromLocal(sid, serverLocal, durMin)
                    : XtreamApi.getTimeshiftUrl(sid, prog['start_utc'] as DateTime? ?? start.toUtc(), durMin);
                Navigator.push(context, slideRoute(PlayerScreen(
                  url: url,
                  title: '${ch.name} — ${prog['title']} (Replay)',
                  streamId: sid,
                  isCatchup: true,
                )));
              } else {
                final url = XtreamApi.getLiveStreamUrl(sid);
                Navigator.push(context, slideRoute(PlayerScreen(
                  url: url,
                  title: '${ch.name}${isCurrent ? ' — ${prog['title']}' : ''}',
                  streamId: sid,
                )));
              }
            },
            onLongPress: () => _showProgramDetail(prog, start, end, desc, channel: ch),
            onSecondaryTap: () => _showProgramDetail(prog, start, end, desc, channel: ch),
            child: Container(
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(3),
                border: cellBorder,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                if (hasReminder)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.notifications_active, size: 10, color: Colors.amber),
                  ),
                Expanded(child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )),
              ]),
            ),
          ),
        ),
      ));

      cursorX = leftPx + widthPx; // advance past this program + gap
    }

    // Fill remaining space
    if (cursorX < totalWidth) {
      cells.add(SizedBox(width: totalWidth - cursorX));
    }

    return Container(
      height: _rowHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        color: i.isEven ? tc.surface : tc.surfaceAlt,
        border: Border(bottom: BorderSide(color: tc.inputFill, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: cells),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surfaceAlt,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.guideTV, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (_loadingEpg)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(AppLocalizations.of(context)!.chargementEpg(_epgLoaded, _channels.length),
                  style: TextStyle(fontSize: 11, color: tc.textDisabled))),
            ),
        ],
      ),
      body: _loadingCats
          ? const SkeletonList(count: 8)
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () { setState(() { _error = null; _loadingCats = true; }); _loadCategories(); },
                  child: Text(AppLocalizations.of(context)!.reessayer)),
            ]))
          : Row(children: [
              // Sidebar catégories (resizable)
              SizedBox(
                width: _catSidebarWidth,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _categories.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final sel = _selectedCatId == '__favorites__';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.star, size: 14,
                              color: sel ? Colors.amber : Colors.amber.withValues(alpha: 0.5)),
                          title: Text(AppLocalizations.of(context)!.favoris, style: TextStyle(fontSize: 12,
                              color: sel ? tc.textPrimary : tc.textSecondary,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          selected: sel,
                          selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => _selectFavorites(),
                        ),
                      );
                    }
                    final category = _categories[i - 1];
                    final id  = category.categoryId;
                    final sel = _selectedCatId == id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        dense: true,
                        title: Text(category.categoryName,
                            style: TextStyle(fontSize: 12,
                                color: sel ? tc.textPrimary : tc.textSecondary,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                            overflow: TextOverflow.ellipsis),
                        selected: sel,
                        selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () => _selectCategory(id),
                      ),
                    );
                  },
                ),
              ),
              // Resize handle
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(() =>
                    _catSidebarWidth = (_catSidebarWidth + d.delta.dx).clamp(_catSidebarMin, _catSidebarMax)),
                  child: Container(width: 6, color: tc.divider),
                ),
              ),
              // Grid zone
              Expanded(
                child: _loadingChannels
                    ? const Center(child: CircularProgressIndicator())
                    : _channels.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context)!.selectionneCategorie,
                        style: TextStyle(color: tc.textDisabled)))
                    : Column(children: [
                        // Day navigation bar
                        EpgDayNavigator(
                          dayStart: _dayStart,
                          canGoPrev: _canGoPrev,
                          canGoNext: _canGoNext,
                          onPrev: () => _changeDay(-1),
                          onNext: () => _changeDay(1),
                          formatDay: _fmtDayFr,
                          onTapDate: () {
                            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                            if (_dayStart != today) {
                              setState(() => _dayStart = today);
                              _changeDay(0);
                            }
                          },
                        ),
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.filtrerChaines,
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          ),
                        ),
                        // Timeline header
                        Row(children: [
                          Container(
                            width: _channelColWidth,
                            height: 30,
                            alignment: Alignment.center,
                            color: AppColors.darkText,
                            child: Text(AppLocalizations.of(context)!.nombreChaines(_filteredChannels.length),
                                style: TextStyle(fontSize: 10, color: tc.textTertiary)),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _headerHScroll,
                              scrollDirection: Axis.horizontal,
                              child: _buildTimelineHeader(),
                            ),
                          ),
                        ]),
                        // Main grid
                        Expanded(
                          child: Row(children: [
                            // Channel names column
                            SizedBox(
                              width: _channelColWidth,
                              child: ListView.builder(
                                controller: _channelVScroll,
                                itemCount: _filteredChannels.length,
                                itemBuilder: (_, i) => _buildChannelRow(i, _filteredChannels),
                              ),
                            ),
                            // Programs grid
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _gridHScroll,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: _hourWidth * 24,
                                  child: ListView.builder(
                                    controller: _gridVScroll,
                                    itemCount: _filteredChannels.length,
                                    itemBuilder: (_, i) => _buildProgramRow(i, _filteredChannels),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ]),
              ),
            ]),
    );
  }
}

