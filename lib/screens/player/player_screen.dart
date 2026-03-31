import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/storage_keys.dart';
import '../../models/app_config.dart';
import '../../services/xtream_api.dart';
import '../../services/watch_progress.dart';
import '../../utils/routes.dart';
import '../../main.dart' show MiniPlayerState, miniPlayerNotifier, showMiniOverlay, miniEntry;
import 'widgets/track_selector.dart';
import 'widgets/quality_badge.dart';
import 'widgets/sleep_timer_dialog.dart';
import 'widgets/next_episode_overlay.dart';
import 'widgets/subtitle_settings.dart';
import 'widgets/epg_overlay.dart';
import 'widgets/player_controls.dart';

// ── Fullscreen back button ──
class _FullscreenBackButton extends StatelessWidget {
  const _FullscreenBackButton();
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    tooltip: 'Quitter le plein ecran',
    onPressed: () => Navigator.of(context).pop(),
  );
}

// ── Player Screen ──
class PlayerScreen extends StatefulWidget {
  final String  url;
  final String  title;
  final String? streamId;          // live -> EPG
  final String? resumeKey;         // VOD/episode -> reprise
  final String? coverUrl;          // cover pour le mini-player
  final Player? existingPlayer;    // restauration depuis mini-player
  final VideoController? existingController;
  // Auto-play next episode
  final Map<String, dynamic>? nextEpisode;
  final String? nextEpisodeCover;
  // Catch-up / replay mode
  final bool isCatchup;
  // Quick zapping (live channel +/-)
  final List<Map<String, dynamic>>? channelList;
  final int? channelIndex;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.streamId,
    this.resumeKey,
    this.coverUrl,
    this.existingPlayer,
    this.existingController,
    this.nextEpisode,
    this.nextEpisodeCover,
    this.isCatchup = false,
    this.channelList,
    this.channelIndex,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _minimized = false;
  bool _buffering = false;
  int _reconnectAttempts = 0;
  String? _playError;

  String? _epgNow;
  String? _epgNext;
  DateTime? _epgNowStart;
  DateTime? _epgNowEnd;
  List<Map<String, String>> _epgListings = [];
  bool _catchupSupported = false;
  BuildContext? _videoCtx;
  List<AudioTrack>    _audioTracks    = [];
  List<SubtitleTrack> _subtitleTracks = [];
  double _speed = 1.0;
  String _aspectRatio = 'auto';
  bool _deinterlace = false;

  // Quality indicator
  String _qualityBadge = '';
  String _bitrate = '';
  Timer? _qualityTimer;

  // Sleep timer
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  Timer? _sleepTick;

  // Auto-play next episode
  bool _showNextOverlay = false;
  Timer? _nextCountdown;
  int _nextCountdownSec = 10;

  // Quick zapping OSD
  String? _zapOsdText;
  Timer? _zapOsdTimer;

  // Subtitle customization
  double _subtitleFontSize = 24;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.5;

  // Position save
  Timer? _saveTimer;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = widget.existingPlayer ?? Player();
    _controller = widget.existingController ?? VideoController(_player);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadSubtitleSettings();

    // Tracks
    _player.stream.tracks.listen((t) {
      if (mounted) {
        final prevAudioCount = _audioTracks.length;
        setState(() {
          _audioTracks    = t.audio;
          _subtitleTracks = t.subtitle;
        });
        if (prevAudioCount <= 1 && t.audio.length > 1) {
          _applyPreferredLanguages();
        }
      }
    });

    // Position tracking + auto-play
    _player.stream.position.listen((pos) {
      _lastPos = pos;
      _checkAutoPlayNext();
    });
    _player.stream.duration.listen((dur) => _lastDur = dur);

    // Buffering
    _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });

    // Auto-reconnect on error (max 3 attempts)
    _player.stream.error.listen((err) {
      if (err.isNotEmpty && mounted && !_minimized) {
        _reconnectAttempts++;
        if (_reconnectAttempts <= 3) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_minimized) _player.open(Media(widget.url));
          });
        } else if (mounted) {
          setState(() {
            _buffering = false;
            _playError = _isCatchupMode
                ? 'Catch-up non disponible pour ce programme.\nLe serveur ne supporte peut-\u00eatre pas le timeshift.'
                : 'Impossible de lire ce flux.\nV\u00e9rifiez votre connexion ou r\u00e9essayez.';
          });
        }
      }
    });
    // Reset reconnect counter on successful play + start quality polling
    _player.stream.playing.listen((playing) {
      if (playing) {
        _reconnectAttempts = 0;
        if (_qualityTimer == null) _startQualityTimer();
      }
    });

    if (widget.streamId != null) _loadEpg();
    if (widget.existingPlayer != null) {
      _startSaveTimer();
    } else if (widget.resumeKey != null) {
      _initResume();
    } else {
      _player.open(Media(widget.url));
    }
  }

  // ── Resume from last position ──
  Future<void> _initResume() async {
    final savedPos = await WatchProgress.getPosition(widget.resumeKey!);
    _player.open(Media(widget.url));
    if (savedPos == null || savedPos.inSeconds < 30) {
      _startSaveTimer();
      return;
    }

    late StreamSubscription sub;
    sub = _player.stream.duration.listen((dur) async {
      if (dur > Duration.zero) {
        await sub.cancel();
        if (!mounted) { _startSaveTimer(); return; }
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkSurface,
            title: Text(AppLocalizations.of(context)!.reprendreLecture),
            content: Text('Continuer depuis ${_fmt(savedPos)} ou repartir depuis le d\u00e9but ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.depuisDebut),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Reprendre \u00e0 ${_fmt(savedPos)}'),
              ),
            ],
          ),
        );
        if (resume == true && mounted) await _player.seek(savedPos);
        _startSaveTimer();
      }
    });
  }

  // ── Auto-play next episode ──
  void _checkAutoPlayNext() {
    if (widget.nextEpisode == null || _showNextOverlay || _minimized) return;
    if (_lastDur.inSeconds < 30) return;
    final ratio = _lastPos.inSeconds / _lastDur.inSeconds;
    if (ratio >= 0.95) {
      _showNextOverlay = true;
      _nextCountdownSec = 10;
      _nextCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) { _nextCountdown?.cancel(); return; }
        setState(() => _nextCountdownSec--);
        if (_nextCountdownSec <= 0) {
          _nextCountdown?.cancel();
          _playNextEpisode();
        }
      });
      if (mounted) setState(() {});
    }
  }

  void _cancelAutoPlay() {
    _nextCountdown?.cancel();
    setState(() => _showNextOverlay = false);
  }

  void _playNextEpisode() {
    _nextCountdown?.cancel();
    final ep = widget.nextEpisode!;
    final epId = ep['id'].toString();
    final url = XtreamApi.getSeriesEpisodeUrl(epId, ep['container_extension'] ?? 'mp4');
    WatchProgress.saveMeta(epId, ep['title'] ?? '', widget.nextEpisodeCover ?? '', url, 'series');
    if (widget.resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(widget.resumeKey!, _lastDur, _lastDur);
    }
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: url,
      title: ep['title'] ?? '',
      resumeKey: epId,
      coverUrl: widget.nextEpisodeCover,
    )));
  }

  // ── Subtitle customization ──
  String get _pid => AppConfig.activeProfileId;

  Future<void> _loadSubtitleSettings() async {
    final p = await SharedPreferences.getInstance();
    final fs = p.getDouble(StorageKeys.subtitleFontSize(_pid));
    final colorVal = p.getInt(StorageKeys.subtitleColor(_pid));
    final bgOp = p.getDouble(StorageKeys.subtitleBgOpacity(_pid));
    if (fs != null) _subtitleFontSize = fs;
    if (colorVal != null) _subtitleColor = Color(colorVal);
    if (bgOp != null) _subtitleBgOpacity = bgOp;
    _applySubtitleSettings();
  }

  Future<void> _saveSubtitleSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(StorageKeys.subtitleFontSize(_pid), _subtitleFontSize);
    await p.setInt(StorageKeys.subtitleColor(_pid), _subtitleColor.toARGB32());
    await p.setDouble(StorageKeys.subtitleBgOpacity(_pid), _subtitleBgOpacity);
  }

  void _applySubtitleSettings() {
    try {
      final np = _player.platform as NativePlayer;
      np.setProperty('sub-font-size', _subtitleFontSize.round().toString());
      final c = _subtitleColor;
      final a = (c.a * 255).round();
      final r = (c.r * 255).round();
      final g = (c.g * 255).round();
      final b = (c.b * 255).round();
      final colorHex = '#${a.toRadixString(16).padLeft(2, '0')}'
          '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
      np.setProperty('sub-color', colorHex.toUpperCase());
      final bgAlpha = (_subtitleBgOpacity * 255).round().toRadixString(16).padLeft(2, '0');
      np.setProperty('sub-back-color', '#${bgAlpha}000000'.toUpperCase());
    } catch (e, st) { AppLogger.warning(LogModule.player, 'Failed to apply subtitle style', error: e, stackTrace: st); }
  }

  void _onSubtitleStylePicker() {
    showSubtitleStylePicker(context,
      fontSize: _subtitleFontSize,
      color: _subtitleColor,
      bgOpacity: _subtitleBgOpacity,
      onFontSizeChanged: (v) {
        setState(() => _subtitleFontSize = v);
        _applySubtitleSettings();
      },
      onColorChanged: (c) {
        setState(() => _subtitleColor = c);
        _applySubtitleSettings();
      },
      onBgOpacityChanged: (v) {
        setState(() => _subtitleBgOpacity = v);
        _applySubtitleSettings();
      },
      onDismissed: _saveSubtitleSettings,
    );
  }

  // ── Aspect ratio ──
  void _setAspectRatio(String ratio) {
    setState(() => _aspectRatio = ratio);
    final np = _player.platform as NativePlayer;
    if (ratio == 'auto') {
      np.setProperty('video-aspect-override', '-1');
    } else if (ratio == 'stretch') {
      final size = MediaQuery.of(context).size;
      np.setProperty('video-aspect-override', '${size.width}:${size.height}');
    } else {
      np.setProperty('video-aspect-override', ratio);
    }
  }

  // ── Deinterlace ──
  void _toggleDeinterlace() {
    setState(() => _deinterlace = !_deinterlace);
    final np = _player.platform as NativePlayer;
    np.setProperty('deinterlace', _deinterlace ? 'yes' : 'no');
  }

  // ── Sleep timer ──
  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _sleepRemaining = duration;
    _sleepTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_sleepRemaining != null) {
        _sleepRemaining = _sleepRemaining! - const Duration(minutes: 1);
        if (_sleepRemaining!.inMinutes <= 0) {
          _player.pause();
          _cancelSleepTimer();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('\u23f0 Minuterie \u00e9coul\u00e9e \u2014 lecture en pause')),
            );
          }
        }
        if (mounted) setState(() {});
      }
    });
    setState(() {});
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    _sleepTimer = null;
    _sleepTick = null;
    _sleepRemaining = null;
    if (mounted) setState(() {});
  }

  // ── Mini-player ──
  void _minimize() {
    _minimized = true;
    final state = MiniPlayerState(
      player: _player,
      controller: _controller,
      title: widget.title,
      coverUrl: widget.coverUrl,
      resumeKey: widget.resumeKey,
      url: widget.url,
    );
    state.startTracking();
    miniPlayerNotifier.value = state;
    showMiniOverlay(state);
    Navigator.of(context).pop();
  }

  void _startSaveTimer() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (widget.resumeKey != null && _lastDur > Duration.zero) {
        WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
      }
    });
  }

  /// Auto-select preferred audio/subtitle language from settings
  Future<void> _applyPreferredLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefAudio = prefs.getString(StorageKeys.prefAudioLang) ?? '';
      final prefSub = prefs.getString(StorageKeys.prefSubLang) ?? '';

      bool matchLang(String trackLang, String pref) {
        if (pref.isEmpty) return false;
        final t = trackLang.toLowerCase();
        final p = pref.toLowerCase();
        if (t == p || t.contains(p) || p.contains(t)) return true;
        const aliases = {
          'fr': ['fre', 'fra', 'french', 'fran\u00e7ais'],
          'en': ['eng', 'english', 'anglais'],
          'de': ['deu', 'ger', 'german', 'deutsch', 'allemand'],
          'es': ['spa', 'spanish', 'espa\u00f1ol', 'espagnol'],
          'it': ['ita', 'italian', 'italiano', 'italien'],
          'pt': ['por', 'portuguese', 'portugais'],
          'ar': ['ara', 'arabic', 'arabe'],
        };
        for (final entry in aliases.entries) {
          final all = [entry.key, ...entry.value];
          if (all.contains(p) && all.contains(t)) return true;
        }
        return false;
      }

      if (prefAudio.isNotEmpty && _audioTracks.length > 1) {
        for (final track in _audioTracks) {
          if (track.language != null && matchLang(track.language!, prefAudio)) {
            _player.setAudioTrack(track);
            break;
          }
        }
      }

      if (prefSub == 'off') {
        final noSub = _subtitleTracks.firstWhere(
          (t) => t.id == 'no' || t.title == 'Disabled',
          orElse: () => SubtitleTrack.no(),
        );
        _player.setSubtitleTrack(noSub);
      } else if (prefSub.isNotEmpty) {
        for (final track in _subtitleTracks) {
          if (track.language != null && matchLang(track.language!, prefSub)) {
            _player.setSubtitleTrack(track);
            break;
          }
        }
      }
    } catch (e, st) { AppLogger.warning(LogModule.player, 'Failed to apply preferred subtitle track', error: e, stackTrace: st); }
  }

  // ── Quality polling ──
  void _startQualityTimer() {
    _updateQualityInfo();
    _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateQualityInfo());
  }

  Future<void> _updateQualityInfo() async {
    try {
      final np = _player.platform as NativePlayer;
      final w = await np.getProperty('video-params/w');
      await np.getProperty('video-params/h');
      final br = await np.getProperty('video-bitrate');
      if (!mounted) return;
      final width = int.tryParse(w) ?? 0;
      String badge = '';
      if (width >= 3840) {
        badge = '4K';
      } else if (width >= 1920) {
        badge = 'FHD';
      } else if (width >= 1280) {
        badge = 'HD';
      } else if (width > 0) {
        badge = 'SD';
      }
      final brNum = double.tryParse(br);
      final brStr = brNum != null && brNum > 0
          ? '${(brNum / 1000000).toStringAsFixed(1)} Mbps'
          : '';
      setState(() {
        _qualityBadge = badge;
        _bitrate = brStr;
      });
    } catch (e, st) {
      AppLogger.warning(LogModule.player, 'Failed to read quality info from player', error: e, stackTrace: st);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    _nextCountdown?.cancel();
    _qualityTimer?.cancel();
    _zapOsdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (!_minimized) {
      if (widget.resumeKey != null && _lastDur > Duration.zero) {
        WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
      }
      if (widget.existingPlayer != null) {
        miniPlayerNotifier.value = null;
        miniEntry?.remove();
        miniEntry = null;
      }
      _player.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Keyboard shortcuts ──
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key   = event.logicalKey;
    final route = ModalRoute.of(context);
    if (route == null) return false;

    if (!route.isCurrent) {
      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyF) {
        Navigator.of(context).pop();
        return true;
      }
      return false;
    }

    final hasZapping = _isLiveMode && widget.channelList != null && widget.channelList!.length > 1;

    if (event is KeyRepeatEvent) {
      if (!_isLiveMode && key == LogicalKeyboardKey.arrowLeft) {
        final p = _lastPos - const Duration(seconds: 10);
        _player.seek(p < Duration.zero ? Duration.zero : p);
        return true;
      }
      if (!_isLiveMode && key == LogicalKeyboardKey.arrowRight) {
        _player.seek(_lastPos + const Duration(seconds: 10));
        return true;
      }
      if (hasZapping && key == LogicalKeyboardKey.arrowUp) {
        _zapChannel(-1);
        return true;
      }
      if (hasZapping && key == LogicalKeyboardKey.arrowDown) {
        _zapChannel(1);
        return true;
      }
      if (!hasZapping && key == LogicalKeyboardKey.arrowUp) {
        _player.setVolume((_player.state.volume + 5).clamp(0.0, 200.0));
        return true;
      }
      if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
        _player.setVolume((_player.state.volume - 5).clamp(0.0, 200.0));
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.space) {
      _player.playOrPause();
      return true;
    }
    if (!_isLiveMode && key == LogicalKeyboardKey.arrowLeft) {
      final p = _lastPos - const Duration(seconds: 10);
      _player.seek(p < Duration.zero ? Duration.zero : p);
      return true;
    }
    if (!_isLiveMode && key == LogicalKeyboardKey.arrowRight) {
      _player.seek(_lastPos + const Duration(seconds: 10));
      return true;
    }
    if (key == LogicalKeyboardKey.keyF) {
      final ctx = _videoCtx;
      if (ctx != null) enterFullscreen(ctx);
      return true;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _player.setVolume(_player.state.volume > 0 ? 0 : 100);
      return true;
    }
    if (hasZapping && key == LogicalKeyboardKey.arrowUp) {
      _zapChannel(-1);
      return true;
    }
    if (hasZapping && key == LogicalKeyboardKey.arrowDown) {
      _zapChannel(1);
      return true;
    }
    if (!hasZapping && key == LogicalKeyboardKey.arrowUp) {
      _player.setVolume((_player.state.volume + 10).clamp(0.0, 200.0));
      return true;
    }
    if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
      _player.setVolume((_player.state.volume - 10).clamp(0.0, 200.0));
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }
    if (_isLiveMode && widget.channelList != null) {
      if (key == LogicalKeyboardKey.keyP) {
        _zapChannel(-1);
        return true;
      }
      if (key == LogicalKeyboardKey.keyN) {
        _zapChannel(1);
        return true;
      }
    }
    return false;
  }

  // ── EPG loading ──
  Future<void> _loadEpg() async {
    try {
      final channelInfoFuture = XtreamApi.getLiveStreams();
      Map<String, dynamic> data;
      try {
        data = await XtreamApi.getFullDayEpg(widget.streamId!);
      } catch (e, st) {
        AppLogger.warning(LogModule.epg, 'Full-day EPG failed, falling back to short EPG', error: e, stackTrace: st);
        data = await XtreamApi.getShortEpg(widget.streamId!, limit: 30);
      }
      bool catchup = false;
      try {
        final allChannels = await channelInfoFuture;
        final thisChannel = allChannels.firstWhere(
          (c) => c['stream_id']?.toString() == widget.streamId,
          orElse: () => <String, dynamic>{},
        );
        catchup = XtreamApi.channelHasCatchup(Map<String, dynamic>.from(thisChannel));
      } catch (e, st) { AppLogger.warning(LogModule.player, 'Failed to check channel catchup support', error: e, stackTrace: st); }
      final listings = data['epg_listings'] as List?;
      if (listings == null || listings.isEmpty) return;
      String dec(String s) { try { return utf8.decode(base64.decode(s)); } catch (e, st) { AppLogger.warning(LogModule.epg, 'Failed to decode base64 EPG string', error: e, stackTrace: st); return s; } }

      DateTime? parseTs(dynamic v) {
        if (v == null) return null;
        final n = int.tryParse(v.toString());
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        return null;
      }
      String fmtTime(DateTime? dt) => dt == null ? '' :
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

      if (!mounted) return;

      final now = DateTime.now();
      final allProgs = listings.map((e) {
        final start = parseTs(e['start_timestamp'] ?? e['start']);
        final end   = parseTs(e['stop_timestamp']  ?? e['stop']);
        final durMin = (start != null && end != null) ? end.difference(start).inMinutes : 0;
        final rawTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
        final rawStartStr = e['start']?.toString();
        return {
          'title': dec(e['title'] ?? ''),
          'description': dec(e['description']?.toString() ?? ''),
          'start': fmtTime(start),
          'end': fmtTime(end),
          'start_ts': start?.millisecondsSinceEpoch.toString() ?? '',
          'end_ts': end?.millisecondsSinceEpoch.toString() ?? '',
          'dur_min': durMin.toString(),
          'start_epoch': rawTs?.toString() ?? '',
          'start_server_local': rawStartStr ?? '',
        };
      }).toList();

      int currentIdx = -1;
      for (var i = 0; i < allProgs.length; i++) {
        final startTs = int.tryParse(allProgs[i]['start_ts'] ?? '');
        final endTs   = int.tryParse(allProgs[i]['end_ts'] ?? '');
        if (startTs != null && endTs != null) {
          final s = DateTime.fromMillisecondsSinceEpoch(startTs);
          final e = DateTime.fromMillisecondsSinceEpoch(endTs);
          if (now.isAfter(s) && now.isBefore(e)) { currentIdx = i; break; }
        }
      }

      setState(() {
        _catchupSupported = catchup;
        _epgListings = allProgs;

        if (currentIdx >= 0) {
          _epgNow  = _epgListings[currentIdx]['title'];
          _epgNext = currentIdx + 1 < _epgListings.length ? _epgListings[currentIdx + 1]['title'] : null;
          final startTs = int.tryParse(_epgListings[currentIdx]['start_ts'] ?? '');
          final endTs   = int.tryParse(_epgListings[currentIdx]['end_ts'] ?? '');
          _epgNowStart = startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs) : null;
          _epgNowEnd   = endTs   != null ? DateTime.fromMillisecondsSinceEpoch(endTs)   : null;
        } else if (_epgListings.isNotEmpty) {
          _epgNow = _epgListings.first['title'];
        }
      });
    } catch (e, st) { AppLogger.warning(LogModule.player, 'Failed to load EPG data', error: e, stackTrace: st); }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  bool get _isLiveMode => widget.streamId != null && !_isCatchupMode && widget.resumeKey == null;
  bool get _isCatchupMode => widget.isCatchup || widget.title.contains('(Replay)');

  // ── Channel zapping ──
  void _zapChannel(int delta) {
    final list = widget.channelList;
    final idx = widget.channelIndex;
    if (list == null || idx == null || list.isEmpty) return;
    final newIdx = (idx + delta) % list.length;
    final ch = list[newIdx];
    final sid = ch['stream_id'].toString();
    final url = XtreamApi.getLiveStreamUrl(sid);
    final name = ch['name'] ?? 'Sans titre';
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: url,
      title: name,
      streamId: sid,
      coverUrl: ch['stream_icon']?.toString(),
      channelList: list,
      channelIndex: newIdx,
    )));
  }

  void _returnToLive() {
    if (widget.streamId == null) return;
    final liveUrl = XtreamApi.getLiveStreamUrl(widget.streamId!);
    final liveTitle = widget.title
        .replaceAll('(Replay)', '')
        .replaceFirst(RegExp(r'^.*? \u2014 '), '')
        .trim();
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: liveUrl,
      title: liveTitle.isEmpty ? 'Live' : liveTitle,
      streamId: widget.streamId,
    )));
  }

  /// Controls builder
  Widget _buildVideoControls(VideoState state) {
    return Builder(builder: (ctx) {
      _videoCtx = ctx;
      return MaterialVideoControls(state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final epgTitle = _epgNow != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            Text(_epgNow!, style: const TextStyle(fontSize: 11, color: Colors.white54),
                overflow: TextOverflow.ellipsis),
          ])
        : Text(widget.title, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis);

    final hasTracks = _audioTracks.length > 1 || _subtitleTracks.length > 1;

    // EPG progress bar
    double? epgProgress;
    if (_epgNowStart != null && _epgNowEnd != null) {
      final now   = DateTime.now();
      final total = _epgNowEnd!.difference(_epgNowStart!).inSeconds;
      if (total > 0) {
        epgProgress = (now.difference(_epgNowStart!).inSeconds / total).clamp(0.0, 1.0);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87, elevation: 0,
        title: epgTitle,
        bottom: epgProgress != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: epgProgress,
                    backgroundColor: Colors.white12,
                    color: AppColors.primaryBlue,
                    minHeight: 4,
                  ),
                ),
              )
            : null,
        actions: [
          if (_isCatchupMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('REPLAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          if (_isCatchupMode && widget.streamId != null)
            TextButton.icon(
              icon: const Icon(Icons.circle, size: 10, color: Colors.redAccent),
              label: const Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _returnToLive,
            ),
          if (_isLiveMode && widget.channelList != null && widget.channelList!.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 22),
              tooltip: 'Cha\u00eene pr\u00e9c\u00e9dente (P)',
              onPressed: () => _zapChannel(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 22),
              tooltip: 'Cha\u00eene suivante (N)',
              onPressed: () => _zapChannel(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
          QualityBadge(qualityBadge: _qualityBadge, bitrate: _bitrate),
          if (_epgListings.length > 1)
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 20),
              tooltip: 'Guide TV',
              onPressed: () => showEpgGuide(context,
                epgListings: _epgListings,
                catchupSupported: _catchupSupported,
                streamId: widget.streamId,
              ),
            ),
          if (_epgNext != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('Suivant : $_epgNext',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                  overflow: TextOverflow.ellipsis)),
            ),
          if (hasTracks)
            IconButton(icon: const Icon(Icons.tune), tooltip: 'Audio / Sous-titres',
                onPressed: () => showTrackPicker(context,
                  player: _player,
                  audioTracks: _audioTracks,
                  subtitleTracks: _subtitleTracks,
                )),
          IconButton(
            icon: const Icon(Icons.subtitles, size: 20),
            tooltip: 'Style sous-titres',
            onPressed: _onSubtitleStylePicker,
          ),
          IconButton(
            icon: const Icon(Icons.aspect_ratio, size: 20),
            tooltip: 'Ratio d\'aspect',
            onPressed: () => showAspectRatioPicker(context,
              currentRatio: _aspectRatio,
              onRatioSelected: _setAspectRatio,
            ),
          ),
          IconButton(
            icon: Icon(Icons.deblur, size: 20,
                color: _deinterlace ? AppColors.primaryBlue : Colors.white),
            tooltip: 'D\u00e9sentrelacement${_deinterlace ? ' (actif)' : ''}',
            onPressed: _toggleDeinterlace,
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Vitesse',
            onPressed: () => showSpeedPicker(context,
              currentSpeed: _speed,
              onSpeedChanged: (v) {
                _player.setRate(v);
                setState(() => _speed = v);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.timer, size: 20,
                color: _sleepRemaining != null ? Colors.amber : Colors.white),
            tooltip: _sleepRemaining != null
                ? 'Veille dans ${_sleepRemaining!.inMinutes} min'
                : 'Minuterie de veille',
            onPressed: () => showSleepTimerPicker(context,
              sleepRemaining: _sleepRemaining,
              onCancel: _cancelSleepTimer,
              onStart: _startSleepTimer,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt, size: 20),
            tooltip: 'Mini-player',
            onPressed: _minimize,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(children: [
        MaterialVideoControlsTheme(
          normal: const MaterialVideoControlsThemeData(
            seekBarMargin: EdgeInsets.fromLTRB(16, 0, 16, 12),
            bottomButtonBarMargin: EdgeInsets.fromLTRB(16, 0, 16, 4),
          ),
          fullscreen: const MaterialVideoControlsThemeData(
            topButtonBar: [_FullscreenBackButton(), Spacer()],
            seekBarMargin: EdgeInsets.fromLTRB(16, 0, 16, 12),
            bottomButtonBarMargin: EdgeInsets.fromLTRB(16, 0, 16, 4),
          ),
          child: Video(controller: _controller, controls: _buildVideoControls),
        ),
        if (_playError != null)
          Center(child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_playError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ]),
          )),
        // Auto-play next episode overlay
        if (_showNextOverlay && widget.nextEpisode != null)
          NextEpisodeOverlay(
            nextEpisode: widget.nextEpisode!,
            countdownSec: _nextCountdownSec,
            onPlayNow: _playNextEpisode,
            onCancel: _cancelAutoPlay,
          ),
      ]),
    );
  }
}
