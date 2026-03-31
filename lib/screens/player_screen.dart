import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unistream/core/logger.dart';
import '../core/storage_keys.dart';
import '../models/app_config.dart';
import '../services/xtream_api.dart';
import '../services/watch_progress.dart';
import '../utils/routes.dart';
import '../main.dart' show MiniPlayerState, miniPlayerNotifier, showMiniOverlay, miniEntry;

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
  final String? streamId;          // live → EPG
  final String? resumeKey;         // VOD/épisode → reprise
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
  List<Map<String, String>> _epgListings = []; // titre + start + end formatés
  bool _catchupSupported = false;
  BuildContext? _videoCtx; // contexte dans la sous-arborescence Video (pour enterFullscreen)
  List<AudioTrack>    _audioTracks    = [];
  List<SubtitleTrack> _subtitleTracks = [];
  double _speed = 1.0;
  String _aspectRatio = 'auto'; // auto, 16:9, 4:3, 2.35:1, stretch
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

  // Sauvegarde de position
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
        final prevSubCount = _subtitleTracks.length;
        setState(() {
          _audioTracks    = t.audio;
          _subtitleTracks = t.subtitle;
        });
        // Auto-select preferred language when tracks first appear
        if (prevAudioCount <= 1 && t.audio.length > 1) {
          _applyPreferredLanguages();
        }
      }
    });

    // Suivi position pour la sauvegarde + auto-play
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
                ? 'Catch-up non disponible pour ce programme.\nLe serveur ne supporte peut-être pas le timeshift.'
                : 'Impossible de lire ce flux.\nVérifiez votre connexion ou réessayez.';
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
      // Restauré depuis mini-player : reprendre le suivi de position
      _startSaveTimer();
    } else if (widget.resumeKey != null) {
      _initResume();
    } else {
      _player.open(Media(widget.url));
    }
  }

  Future<void> _initResume() async {
    final savedPos = await WatchProgress.getPosition(widget.resumeKey!);
    _player.open(Media(widget.url));
    if (savedPos == null || savedPos.inSeconds < 30) {
      _startSaveTimer();
      return;
    }

    // Attend que la durée soit connue, puis propose le choix
    late StreamSubscription sub;
    sub = _player.stream.duration.listen((dur) async {
      if (dur > Duration.zero) {
        await sub.cancel();
        if (!mounted) { _startSaveTimer(); return; }
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: const Text('Reprendre la lecture ?'),
            content: Text('Continuer depuis ${_fmt(savedPos)} ou repartir depuis le début ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Depuis le début'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Reprendre à ${_fmt(savedPos)}'),
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
    if (_lastDur.inSeconds < 30) return; // pas de durée fiable
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
    // Sauver la progression actuelle à 100%
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

  void _showSubtitleStylePicker() {
    final colorOptions = <(Color, String)>[
      (Colors.white, 'Blanc'),
      (Colors.yellow, 'Jaune'),
      (Colors.green, 'Vert'),
      (Colors.cyan, 'Cyan'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Style des sous-titres',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('Taille', style: TextStyle(fontSize: 13, color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _subtitleFontSize,
                    min: 12, max: 48, divisions: 18,
                    label: _subtitleFontSize.round().toString(),
                    activeColor: const Color(0xFF4A90D9),
                    onChanged: (v) {
                      setState(() => _subtitleFontSize = v);
                      setLocal(() {});
                      _applySubtitleSettings();
                    },
                  ),
                ),
                Text('${_subtitleFontSize.round()}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Text('Couleur', style: TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(width: 16),
                ...colorOptions.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _subtitleColor = opt.$1);
                      setLocal(() {});
                      _applySubtitleSettings();
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: opt.$1, shape: BoxShape.circle,
                        border: Border.all(
                          color: _subtitleColor.toARGB32() == opt.$1.toARGB32()
                              ? const Color(0xFF4A90D9) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('Fond', style: TextStyle(fontSize: 13, color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _subtitleBgOpacity,
                    min: 0, max: 1, divisions: 10,
                    label: '${(_subtitleBgOpacity * 100).round()}%',
                    activeColor: const Color(0xFF4A90D9),
                    onChanged: (v) {
                      setState(() => _subtitleBgOpacity = v);
                      setLocal(() {});
                      _applySubtitleSettings();
                    },
                  ),
                ),
                Text('${(_subtitleBgOpacity * 100).round()}%',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    ).then((_) => _saveSubtitleSettings());
  }

  // ── Aspect ratio ──
  void _showAspectRatioPicker() {
    final options = [
      ('auto', 'Auto'),
      ('16:9', '16:9'),
      ('4:3', '4:3'),
      ('2.35:1', '2.35:1'),
      ('stretch', 'Étirer'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ratio d\'aspect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final (value, label) in options)
              ListTile(
                dense: true,
                leading: Icon(
                  _aspectRatio == value ? Icons.check_circle : Icons.circle_outlined,
                  color: _aspectRatio == value ? const Color(0xFF4A90D9) : Colors.white38,
                  size: 20,
                ),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  _setAspectRatio(value);
                },
              ),
          ],
        ),
      ),
    );
  }

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
  void _showSleepTimerPicker() {
    final presets = [15, 30, 45, 60, 90, 120];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Minuterie de veille', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (_sleepRemaining != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                title: Text('Annuler (${_sleepRemaining!.inMinutes} min restantes)',
                    style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _cancelSleepTimer();
                },
              ),
            for (final m in presets)
              ListTile(
                dense: true,
                leading: const Icon(Icons.timer, color: Colors.white38, size: 20),
                title: Text('$m minutes'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startSleepTimer(Duration(minutes: m));
                },
              ),
          ],
        ),
      ),
    );
  }

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
              const SnackBar(content: Text('⏰ Minuterie écoulée — lecture en pause')),
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

      // Fuzzy language matching helper
      bool matchLang(String trackLang, String pref) {
        if (pref.isEmpty) return false;
        final t = trackLang.toLowerCase();
        final p = pref.toLowerCase();
        // Direct match or contains
        if (t == p || t.contains(p) || p.contains(t)) return true;
        // Common aliases
        const aliases = {
          'fr': ['fre', 'fra', 'french', 'français'],
          'en': ['eng', 'english', 'anglais'],
          'de': ['deu', 'ger', 'german', 'deutsch', 'allemand'],
          'es': ['spa', 'spanish', 'español', 'espagnol'],
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

      // Apply preferred audio
      if (prefAudio.isNotEmpty && _audioTracks.length > 1) {
        for (final track in _audioTracks) {
          if (track.language != null && matchLang(track.language!, prefAudio)) {
            _player.setAudioTrack(track);
            break;
          }
        }
      }

      // Apply preferred subtitle
      if (prefSub == 'off') {
        // Disable subtitles
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

  void _startQualityTimer() {
    _updateQualityInfo();
    _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateQualityInfo());
  }

  Future<void> _updateQualityInfo() async {
    try {
      final np = _player.platform as NativePlayer;
      final w = await np.getProperty('video-params/w');
      await np.getProperty('video-params/h'); // query height to keep mpv updated
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
      // Si restauré depuis mini-player, nettoyer l'overlay et le notifier
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

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key   = event.logicalKey;
    final route = ModalRoute.of(context);
    if (route == null) return false;

    // Quitter le plein écran (Esc ou F)
    if (!route.isCurrent) {
      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyF) {
        Navigator.of(context).pop();
        return true;
      }
      return false;
    }

    final hasZapping = _isLiveMode && widget.channelList != null && widget.channelList!.length > 1;

    // Raccourcis en mode normal — on gère tout pour éviter que l'AppBar vole le focus
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
      // enterFullscreen requiert un contexte dans la sous-arborescence Video
      final ctx = _videoCtx;
      if (ctx != null) enterFullscreen(ctx);
      return true;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _player.setVolume(_player.state.volume > 0 ? 0 : 100);
      return true;
    }
    // Zapping: flèches haut/bas en live, volume sinon
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
    // Quick zapping: P/N toujours disponibles en live
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

  Future<void> _loadEpg() async {
    try {
      // Load full-day EPG (past+future) + channel info for catchup detection
      final channelInfoFuture = XtreamApi.getLiveStreams();
      Map<String, dynamic> data;
      try {
        data = await XtreamApi.getFullDayEpg(widget.streamId!);
      } catch (e, st) {
        AppLogger.warning(LogModule.epg, 'Full-day EPG failed, falling back to short EPG', error: e, stackTrace: st);
        data = await XtreamApi.getShortEpg(widget.streamId!, limit: 30);
      }
      // Check if this channel has tv_archive=1
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
        // Store raw UTC timestamp for timeshift URL
        final rawTs = int.tryParse((e['start_timestamp'] ?? e['start'] ?? '').toString());
        // Store server-local start string for DST-safe timeshift URL
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

      // Find current program
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

  void _showEpgGuide() {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        // Find current program index for auto-scroll
        int currentIdx = 0;
        for (var i = 0; i < _epgListings.length; i++) {
          final endTs = int.tryParse(_epgListings[i]['end_ts'] ?? '');
          if (endTs != null && now.isBefore(DateTime.fromMillisecondsSinceEpoch(endTs))) {
            currentIdx = i;
            break;
          }
        }
        final scrollCtrl = ScrollController(
          initialScrollOffset: (currentIdx * 56.0 - 100).clamp(0, double.infinity),
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, ctrl) => Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Guide TV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _epgListings.length,
                itemBuilder: (_, i) {
                  final prog = _epgListings[i];
                  final startTs = int.tryParse(prog['start_ts'] ?? '');
                  final endTs   = int.tryParse(prog['end_ts'] ?? '');
                  final durMin  = int.tryParse(prog['dur_min'] ?? '0') ?? 0;

                  // Determine past / current / future
                  bool isPast = false;
                  bool isCurrent = false;
                  if (startTs != null && endTs != null) {
                    final s = DateTime.fromMillisecondsSinceEpoch(startTs);
                    final e = DateTime.fromMillisecondsSinceEpoch(endTs);
                    isCurrent = now.isAfter(s) && now.isBefore(e);
                    isPast = now.isAfter(e);
                  }

                  final progDesc = prog['description'] ?? '';
                  return ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 44,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(prog['start'] ?? '',
                            style: TextStyle(fontSize: 11,
                                color: isCurrent ? const Color(0xFF4A90D9) : isPast ? Colors.white24 : Colors.white38)),
                        if (isPast)
                          const Text('passé', style: TextStyle(fontSize: 8, color: Colors.white24))
                        else if (isCurrent)
                          const Text('EN COURS', style: TextStyle(fontSize: 8, color: Color(0xFF4A90D9), fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    title: Text(prog['title'] ?? '',
                        style: TextStyle(fontSize: 13,
                            color: isCurrent ? Colors.white : isPast ? Colors.white38 : Colors.white70,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prog['end']?.isNotEmpty == true)
                          Text('→ ${prog['end']}', style: TextStyle(fontSize: 10,
                              color: isPast ? Colors.white12 : Colors.white24)),
                        if (progDesc.isNotEmpty)
                          Text(progDesc, style: TextStyle(fontSize: 10,
                              color: isPast ? Colors.white24 : Colors.white38),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: (_catchupSupported && isPast && startTs != null && widget.streamId != null)
                        ? TextButton.icon(
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text('Revoir', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              // Prefer server-local string (DST-safe), fallback to UTC conversion
                              final serverLocal = prog['start_server_local'] as String? ?? '';
                              String url;
                              if (serverLocal.isNotEmpty) {
                                url = XtreamApi.getTimeshiftUrlFromLocal(widget.streamId!, serverLocal, durMin);
                              } else {
                                final rawEpoch = int.tryParse(prog['start_epoch'] ?? '');
                                final startUtc = rawEpoch != null
                                    ? DateTime.fromMillisecondsSinceEpoch(rawEpoch * 1000, isUtc: true)
                                    : DateTime.fromMillisecondsSinceEpoch(startTs, isUtc: true);
                                url = XtreamApi.getTimeshiftUrl(widget.streamId!, startUtc, durMin);
                              }
                              Navigator.pushReplacement(context, slideRoute(PlayerScreen(
                                url: url,
                                title: '${prog['title']} (Replay)',
                                streamId: widget.streamId,
                                isCatchup: true,
                              )));
                            },
                          )
                        : null,
                    tileColor: isCurrent ? const Color(0xFF4A90D9).withValues(alpha: 0.1) : null,
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  void _showTrackPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TrackPickerSheet(
          player: _player, audioTracks: _audioTracks, subtitleTracks: _subtitleTracks),
    );
  }

  void _showSpeedPicker() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Vitesse de lecture',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            ...speeds.map((sp) => RadioListTile<double>(
              dense: true,
              title: Text(sp == 1.0 ? 'Normale (1×)' : '${sp}×',
                  style: const TextStyle(fontSize: 13)),
              value: sp,
              groupValue: _speed,
              activeColor: const Color(0xFF4A90D9),
              onChanged: (v) {
                if (v == null) return;
                _player.setRate(v);
                setState(() => _speed = v);
                setLocal(() {});
              },
            )),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  /// Controls builder : le Builder interne est un descendant du _FullscreenInheritedWidget
  /// fourni par Video, ce qui permet à enterFullscreen(ctx) de fonctionner.
  Widget _buildVideoControls(VideoState state) {
    return Builder(builder: (ctx) {
      _videoCtx = ctx;
      return MaterialVideoControls(state);
    });
  }

  bool get _isLiveMode => widget.streamId != null && !_isCatchupMode && widget.resumeKey == null;

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

  bool get _isCatchupMode => widget.isCatchup || widget.title.contains('(Replay)');

  void _returnToLive() {
    if (widget.streamId == null) return;
    final liveUrl = XtreamApi.getLiveStreamUrl(widget.streamId!);
    // Strip "(Replay)" and replay prefix from title
    final liveTitle = widget.title
        .replaceAll('(Replay)', '')
        .replaceFirst(RegExp(r'^.*? — '), '')
        .trim();
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: liveUrl,
      title: liveTitle.isEmpty ? 'Live' : liveTitle,
      streamId: widget.streamId,
    )));
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

    // Barre de progression EPG
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
                    color: const Color(0xFF4A90D9),
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
              tooltip: 'Chaîne précédente (P)',
              onPressed: () => _zapChannel(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 22),
              tooltip: 'Chaîne suivante (N)',
              onPressed: () => _zapChannel(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
          if (_qualityBadge.isNotEmpty)
            Tooltip(
              message: _bitrate.isNotEmpty ? _bitrate : _qualityBadge,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _qualityBadge == '4K' ? Colors.amber
                       : _qualityBadge == 'FHD' ? Colors.green
                       : _qualityBadge == 'HD' ? Colors.blue
                       : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_qualityBadge,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (_bitrate.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(_bitrate,
                        style: const TextStyle(fontSize: 9, color: Colors.white70)),
                  ],
                ]),
              ),
            ),
          if (_epgListings.length > 1)
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 20),
              tooltip: 'Guide TV',
              onPressed: _showEpgGuide,
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
                onPressed: _showTrackPicker),
          IconButton(
            icon: const Icon(Icons.subtitles, size: 20),
            tooltip: 'Style sous-titres',
            onPressed: _showSubtitleStylePicker,
          ),
          IconButton(
            icon: const Icon(Icons.aspect_ratio, size: 20),
            tooltip: 'Ratio d\'aspect',
            onPressed: _showAspectRatioPicker,
          ),
          IconButton(
            icon: Icon(Icons.deblur, size: 20,
                color: _deinterlace ? const Color(0xFF4A90D9) : Colors.white),
            tooltip: 'Désentrelacement${_deinterlace ? ' (actif)' : ''}',
            onPressed: _toggleDeinterlace,
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Vitesse',
            onPressed: _showSpeedPicker,
          ),
          IconButton(
            icon: Icon(Icons.timer, size: 20,
                color: _sleepRemaining != null ? Colors.amber : Colors.white),
            tooltip: _sleepRemaining != null
                ? 'Veille dans ${_sleepRemaining!.inMinutes} min'
                : 'Minuterie de veille',
            onPressed: _showSleepTimerPicker,
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
        // Note: MaterialVideoControls already shows its own buffering indicator.
        // We only show ours when there's no video at all (e.g. initial load before controls appear).
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
          Positioned(bottom: 80, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A90D9), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('Épisode suivant', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(widget.nextEpisode!['title'] ?? 'Épisode suivant',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      onPressed: _playNextEpisode,
                      child: Text('Lire maintenant ($_nextCountdownSec)'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _cancelAutoPlay,
                      child: const Text('Annuler'),
                    ),
                  ]),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ── Résolution codes langue ISO 639 ──
const _langNames = {
  'und': 'Indéfini',
  'fr': 'Français',  'fre': 'Français',  'fra': 'Français',
  'en': 'Anglais',   'eng': 'Anglais',
  'es': 'Espagnol',  'spa': 'Espagnol',
  'de': 'Allemand',  'ger': 'Allemand',  'deu': 'Allemand',
  'it': 'Italien',   'ita': 'Italien',
  'pt': 'Portugais', 'por': 'Portugais',
  'ar': 'Arabe',     'ara': 'Arabe',
  'ru': 'Russe',     'rus': 'Russe',
  'zh': 'Chinois',   'chi': 'Chinois',   'zho': 'Chinois',
  'ja': 'Japonais',  'jpn': 'Japonais',
  'nl': 'Néerlandais','dut': 'Néerlandais','nld': 'Néerlandais',
  'pl': 'Polonais',  'pol': 'Polonais',
  'tr': 'Turc',      'tur': 'Turc',
  'sv': 'Suédois',   'swe': 'Suédois',
  'no': 'Norvégien', 'nor': 'Norvégien',
  'da': 'Danois',    'dan': 'Danois',
  'fi': 'Finnois',   'fin': 'Finnois',
  'he': 'Hébreu',    'heb': 'Hébreu',
  'ko': 'Coréen',    'kor': 'Coréen',
};

String _resolveTrackLabel(String? title, String? language, String? id, String fallback) {
  final langName    = language != null ? _langNames[language.toLowerCase()] : null;
  final langDisplay = langName ?? (language?.isNotEmpty == true ? language!.toUpperCase() : null);
  if (title != null && title.isNotEmpty) {
    return langDisplay != null ? '$title ($langDisplay)' : title;
  }
  return langDisplay ?? id ?? fallback;
}

// ── Track Picker ──
class _TrackPickerSheet extends StatefulWidget {
  final Player player;
  final List<AudioTrack>    audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  const _TrackPickerSheet({required this.player, required this.audioTracks, required this.subtitleTracks});
  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet> {
  late AudioTrack    _curAudio;
  late SubtitleTrack _curSub;

  @override
  void initState() {
    super.initState();
    _curAudio = widget.player.state.track.audio;
    _curSub   = widget.player.state.track.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const TabBar(
          tabs: [Tab(text: 'Audio'), Tab(text: 'Sous-titres')],
          indicatorColor: Color(0xFF4A90D9),
        ),
        SizedBox(height: 280, child: TabBarView(children: [
          // Audio
          ListView(children: widget.audioTracks.map((t) => RadioListTile<AudioTrack>(
            title: Text(_resolveTrackLabel(t.title, t.language, t.id, 'Piste audio'),
                style: const TextStyle(fontSize: 13)),
            value: t, groupValue: _curAudio,
            activeColor: const Color(0xFF4A90D9),
            onChanged: (v) {
              if (v == null) return;
              widget.player.setAudioTrack(v);
              setState(() => _curAudio = v);
            },
          )).toList()),
          // Sous-titres
          ListView(children: [
            RadioListTile<SubtitleTrack>(
              title: const Text('Désactivés', style: TextStyle(fontSize: 13)),
              value: SubtitleTrack.no(), groupValue: _curSub,
              activeColor: const Color(0xFF4A90D9),
              onChanged: (v) {
                if (v == null) return;
                widget.player.setSubtitleTrack(v);
                setState(() => _curSub = v);
              },
            ),
            ...widget.subtitleTracks.map((t) => RadioListTile<SubtitleTrack>(
              title: Text(_resolveTrackLabel(t.title, t.language, t.id, 'Sous-titres'),
                  style: const TextStyle(fontSize: 13)),
              value: t, groupValue: _curSub,
              activeColor: const Color(0xFF4A90D9),
              onChanged: (v) {
                if (v == null) return;
                widget.player.setSubtitleTrack(v);
                setState(() => _curSub = v);
              },
            )),
          ]),
        ])),
      ]),
    );
  }
}
