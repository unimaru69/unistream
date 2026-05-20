import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../services/connectivity_service.dart';
import '../../repositories/preferences_repository.dart';
import 'package:unistream/core/logger.dart';
import '../../core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../models/app_config.dart';
import '../../models/channel.dart';
import '../../models/next_episode_info.dart';
import '../../repositories/content_repository.dart';
import '../../services/watch_progress.dart';
import '../../utils/content_key.dart';
import '../../utils/routes.dart';
import '../../main.dart' show MiniPlayerState, miniPlayerNotifier, showMiniOverlay, miniEntry;
import '../../services/auth_service.dart';
import '../../utils/feature_access.dart';
import '../../widgets/premium_gate.dart';
import 'widgets/cinematic_controls.dart';
import 'widgets/next_episode_overlay.dart';
import 'widgets/player_controls.dart';
import 'widgets/sleep_timer_dialog.dart';
import 'widgets/subtitle_settings.dart';
import 'widgets/track_selector.dart';
import 'widgets/volume_osd.dart';
import 'widgets/channel_list_overlay.dart';
import 'widgets/channel_number_osd.dart';
import 'widgets/timeshift_osd.dart';
import 'widgets/player_app_bar.dart';
import 'widgets/quality_selector.dart';
import 'channel_zapping_controller.dart';
import 'ios_player_screen.dart';
import 'player_keyboard_handler.dart';

// ── Fullscreen back button ──
class _FullscreenBackButton extends StatelessWidget {
  const _FullscreenBackButton();
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    tooltip: AppLocalizations.of(context)!.quitterPleinEcran,
    onPressed: () => Navigator.of(context).pop(),
  );
}

// ── Player Screen ──
/// Public facade — picks the right backend at build time. Call sites pass
/// the same parameters as before; on iOS / iPadOS we route to AVPlayer via
/// `IOSPlayerScreen` because media_kit (libmpv) doesn't run there.
class PlayerScreen extends StatelessWidget {
  final String  url;
  final String  title;
  final String? streamId;
  final String? resumeKey;
  final String? coverUrl;
  final Player? existingPlayer;        // ignored on iOS
  final VideoController? existingController; // ignored on iOS
  final NextEpisodeInfo? nextEpisode;
  final bool isCatchup;
  final List<Channel>? channelList;
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
    this.isCatchup = false,
    this.channelList,
    this.channelIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return IOSPlayerScreen(
        url: url,
        title: title,
        streamId: streamId,
        resumeKey: resumeKey,
        coverUrl: coverUrl,
        nextEpisode: nextEpisode,
        isCatchup: isCatchup,
        channelList: channelList,
        channelIndex: channelIndex,
      );
    }
    return _MediaKitPlayerScreen(
      url: url,
      title: title,
      streamId: streamId,
      resumeKey: resumeKey,
      coverUrl: coverUrl,
      existingPlayer: existingPlayer,
      existingController: existingController,
      nextEpisode: nextEpisode,
      isCatchup: isCatchup,
      channelList: channelList,
      channelIndex: channelIndex,
    );
  }
}

/// Private media_kit-backed implementation (used on macOS, Linux, Windows,
/// Android).
class _MediaKitPlayerScreen extends StatefulWidget {
  final String  url;
  final String  title;
  final String? streamId;          // live -> EPG
  final String? resumeKey;         // VOD/episode -> reprise
  final String? coverUrl;          // cover pour le mini-player
  final Player? existingPlayer;    // restauration depuis mini-player
  final VideoController? existingController;
  // Auto-play next episode
  final NextEpisodeInfo? nextEpisode;
  // Catch-up / replay mode
  final bool isCatchup;
  // Quick zapping (live channel +/-)
  final List<Channel>? channelList;
  final int? channelIndex;

  const _MediaKitPlayerScreen({
    required this.url,
    required this.title,
    this.streamId,
    this.resumeKey,
    this.coverUrl,
    this.existingPlayer,
    this.existingController,
    this.nextEpisode,
    this.isCatchup = false,
    this.channelList,
    this.channelIndex,
  });
  @override
  State<_MediaKitPlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_MediaKitPlayerScreen> {
  final _prefs = PreferencesRepository();
  final _repo = ContentRepository();
  late final Player _player;
  late final VideoController _controller;
  bool _minimized = false;
  int _reconnectAttempts = 0;
  String? _playError;

  String? _epgNow;
  String? _epgNext;
  DateTime? _epgNowStart;
  DateTime? _epgNowEnd;
  List<Map<String, String>> _epgListings = [];
  bool _catchupSupported = false;
  // 30 s tick that recomputes the current programme + triggers a
  // rebuild so the live-overlay progress bar advances with the
  // wall-clock. Mirror of `_IOSPlayerScreenState._epgTickTimer`.
  Timer? _epgTickTimer;
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

  // HLS variant selection
  List<HlsVariant> _hlsVariants = [];
  String? _activeVariantUrl;

  // Sleep timer
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  Timer? _sleepTick;

  // Auto-play next episode
  bool _showNextOverlay = false;
  Timer? _nextCountdown;
  int _nextCountdownSec = 10;

  // Quick zapping OSD
  Timer? _zapOsdTimer;

  // Volume OSD
  bool _showVolumeOsd = false;
  Timer? _volumeOsdTimer;

  // Channel zapping controller
  late final ChannelZappingController _zapping;

  // Subtitle customization
  double _subtitleFontSize = 24;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.5;

  // Stream subscriptions
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _playingSubscription;

  // Position save
  Timer? _saveTimer;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;

  // Connectivity monitoring
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.online;
  bool _showConnectivityBanner = false;

  // Live timeshift ──
  // offsetSec == 0 → playing the HLS live URL.
  // offsetSec  > 0 → playing an Xtream timeshift TS URL N seconds
  // behind live. Mirror of tvOS `VLCLivePlayerViewController`.
  // Step sizes (seconds) used by `handlePlayerKeyEvent` when the user
  // presses ←/→ in live mode — short = single tap, long = Shift held.
  int _timeshiftOffsetSec = 0;
  String? _timeshiftFlashMessage;
  Timer? _timeshiftFlashTimer;

  @override
  void initState() {
    super.initState();
    _zapping = ChannelZappingController(
      channelList: widget.channelList,
      channelIndex: widget.channelIndex,
      onStateChanged: () { if (mounted) setState(() {}); },
      repo: _repo,
    );
    _player = widget.existingPlayer ?? Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    // On Linux, force software decoding for maximum compatibility.
    // Do NOT set vo/gpu-context — media_kit manages its own texture pipeline.
    if (Platform.isLinux) {
      final nativePlayer = _player.platform;
      if (nativePlayer is NativePlayer) {
        nativePlayer.setProperty('hwdec', 'no');
      }
    }
    _controller = widget.existingController ?? VideoController(_player);

    // Only force immersive/landscape on mobile platforms
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadSubtitleSettings();
    _detectHlsVariants();

    // Tracks
    _tracksSubscription = _player.stream.tracks.listen((t) {
      if (!mounted) return;
      final prevAudioCount = _audioTracks.length;
      setState(() {
        _audioTracks    = t.audio;
        _subtitleTracks = t.subtitle;
      });
      if (prevAudioCount <= 1 && t.audio.length > 1) {
        _applyPreferredLanguages();
      }
    });

    // Position tracking + auto-play
    _positionSubscription = _player.stream.position.listen((pos) {
      _lastPos = pos;
      _checkAutoPlayNext();
    });
    _durationSubscription = _player.stream.duration.listen((dur) => _lastDur = dur);

    // Auto-reconnect on error (max 3 attempts)
    _errorSubscription = _player.stream.error.listen((err) {
      if (err.isNotEmpty && mounted && !_minimized) {
        _reconnectAttempts++;
        if (_reconnectAttempts <= 3) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted || _minimized) return;
            _player.open(Media(widget.url));
          });
        } else {
          if (!mounted) return;
          setState(() {
            _playError = _isCatchupMode
                ? AppLocalizations.of(context)!.catchupNonDisponible
                : AppLocalizations.of(context)!.impossibleLireFlux;
          });
        }
      }
    });
    // Reset reconnect counter on successful play + start quality polling
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) {
        _reconnectAttempts = 0;
        AppLogger.breadcrumb('player', 'Playback started', data: {'title': widget.title});
        if (_qualityTimer == null) _startQualityTimer();
      }
    });

    // Connectivity monitoring
    _connectivitySubscription = _connectivityService.statusStream.listen((status) {
      if (!mounted || _minimized) return;
      final wasDown = _connectivityStatus != ConnectivityStatus.online;
      setState(() => _connectivityStatus = status);

      if (status == ConnectivityStatus.offline) {
        setState(() => _showConnectivityBanner = true);
      } else if (status == ConnectivityStatus.reconnecting) {
        // Keep banner visible during reconnection attempt
        setState(() => _showConnectivityBanner = true);
      } else if (status == ConnectivityStatus.online && wasDown) {
        // Auto-retry stream on reconnection
        _reconnectAttempts = 0;
        _player.open(Media(widget.url));
        // Show "Connexion rétablie" briefly, then hide
        setState(() => _showConnectivityBanner = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showConnectivityBanner = false);
        });
      } else if (status == ConnectivityStatus.online) {
        // Already online, dismiss any lingering banner
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _showConnectivityBanner = false);
        });
      }
    });

    if (widget.streamId != null) {
      _loadEpg();
      // Refresh the EPG progress bar + advance to the next programme
      // when the current one rolls past its end. Cheap setState
      // scoped to the live overlay; doesn't touch the video pipeline.
      _epgTickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted || !_isLiveMode || _epgListings.isEmpty) return;
        setState(() => _advanceLiveEpgCurrent());
      });
    }
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
        final tc = AppThemeColors.of(context);
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: tc.surface,
            title: Text(AppLocalizations.of(context)!.reprendreLecture),
            content: Text(AppLocalizations.of(context)!.continuerOuDebut(_fmt(savedPos))),
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
                child: Text(AppLocalizations.of(context)!.reprendreDepuis(_fmt(savedPos))),
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
    final epKey = ContentKey.make(ContentKey.episode, ep.id);
    final url = _repo.getSeriesEpisodeUrl(ep.id, ep.containerExtension);
    WatchProgress.saveMeta(epKey, ep.title, ep.coverUrl ?? '', url, 'series');
    if (widget.resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(widget.resumeKey!, _lastDur, _lastDur);
    }
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: url,
      title: ep.title,
      resumeKey: epKey,
      coverUrl: ep.coverUrl,
    )));
  }

  // ── Subtitle customization ──
  String get _pid => AppConfig.activeProfileId;

  Future<void> _loadSubtitleSettings() async {
    final s = await _prefs.getSubtitleSettings(_pid);
    _subtitleFontSize = s.fontSize;
    _subtitleColor = s.color;
    _subtitleBgOpacity = s.bgOpacity;
    _applySubtitleSettings();
  }

  Future<void> _saveSubtitleSettings() async {
    await _prefs.setSubtitleSettings(_pid, SubtitleSettings(
      fontSize: _subtitleFontSize,
      color: _subtitleColor,
      bgOpacity: _subtitleBgOpacity,
    ));
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
    if (!_checkFeature(Feature.advancedSubtitles)) return;
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

  // ── HLS variant detection ──
  Future<void> _detectHlsVariants() async {
    if (!widget.url.contains('.m3u8')) return;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(widget.url));
      final response = await request.close();
      if (response.statusCode != 200) return;
      final body = await response.transform(const Utf8Decoder()).join();
      client.close(force: true);
      final variants = parseHlsMasterPlaylist(body, widget.url);
      if (mounted && variants.isNotEmpty) {
        setState(() => _hlsVariants = variants);
      }
    } catch (e) {
      AppLogger.warning(LogModule.player, 'Failed to fetch HLS variants', error: e);
    }
  }

  void _selectVariant(HlsVariant? variant) {
    if (variant == null) {
      // Auto — reload original URL
      setState(() => _activeVariantUrl = null);
      _player.open(Media(widget.url));
    } else {
      setState(() => _activeVariantUrl = variant.url);
      _player.open(Media(variant.url));
    }
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

  /// Tap-to-cycle aspect — wired to the drawer's aspect button so the
  /// user can step through ratios without opening a sheet (matches the
  /// tvOS `onCycleAspect` pattern).
  static const _aspectCycle = <String>['auto', '16:9', '4:3', '2.35:1', 'stretch'];
  void _cycleAspectRatio() {
    final i = _aspectCycle.indexOf(_aspectRatio);
    final next = _aspectCycle[(i + 1) % _aspectCycle.length];
    _setAspectRatio(next);
  }

  /// Short, button-friendly label for the current aspect ratio.
  String get _aspectRatioLabel {
    switch (_aspectRatio) {
      case 'auto':
        return 'Auto';
      case 'stretch':
        return 'Étirer';
      case '2.35:1':
        return '2.35';
      default:
        return _aspectRatio;
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
              SnackBar(content: Text(AppLocalizations.of(context)!.minuterieEcoulee)),
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

  /// Imperative feature gate for the player (no WidgetRef available).
  bool _checkFeature(Feature feature) {
    final account = AuthService.instance.cachedAccountInfo;
    if (FeatureAccess.canUse(feature, account)) return true;
    showPremiumRequiredDialog(context);
    return false;
  }

  // ── Mini-player ──
  void _minimize() {
    if (!_checkFeature(Feature.miniPlayer)) return;
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
    // Save every 30s — not 5s. WatchProgress.save() chains three awaits
    // on SharedPreferences (getInstance + setInt x2), which writes a
    // JSON file with fsync. On Linux ext4/btrfs that fsync occasionally
    // pre-empts the rendering microtask just enough to drop a frame,
    // producing a visible image stutter every 5s during VOD playback
    // (live streams don't have a resumeKey, hence no stutter there).
    // We still call WatchProgress.save explicitly on pause / seek /
    // dispose / minimize-to-mini-player so the user never loses more
    // than ~30s of progress in the worst case (a hard crash mid-play).
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.resumeKey != null && _lastDur > Duration.zero) {
        WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
      }
    });
  }

  /// Auto-select preferred audio/subtitle language from settings
  Future<void> _applyPreferredLanguages() async {
    try {
      final prefAudio = await _prefs.getPreferredAudioLang() ?? '';
      final prefSub = await _prefs.getPreferredSubLang() ?? '';

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
    // Cancel stream subscriptions first
    _connectivitySubscription?.cancel();
    _tracksSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    _playingSubscription?.cancel();
    // Cancel timers
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    _nextCountdown?.cancel();
    _qualityTimer?.cancel();
    _zapOsdTimer?.cancel();
    _volumeOsdTimer?.cancel();
    _timeshiftFlashTimer?.cancel();
    _epgTickTimer?.cancel();
    _zapping.dispose();
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
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  // ── Keyboard shortcuts ──
  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    if (route == null) return false;

    return handlePlayerKeyEvent(
      event,
      callbacks: PlayerKeyCallbacks(
        playPause: _player.playOrPause,
        seek: (delta) {
          final target = _lastPos + delta;
          _player.seek(target < Duration.zero ? Duration.zero : target);
        },
        adjustVolume: (delta) {
          _player.setVolume((_player.state.volume + delta).clamp(0.0, 200.0));
        },
        toggleMute: () {
          _player.setVolume(_player.state.volume > 0 ? 0 : 100);
        },
        enterFullscreen: () {
          final ctx = _videoCtx;
          if (ctx != null) enterFullscreen(ctx);
        },
        escape: () => Navigator.of(context).pop(),
        zapChannel: _zapChannel,
        onVolumeOsd: _showVolumeOsdBriefly,
        toggleChannelList: _zapping.toggleChannelList,
        onDigitInput: _zapping.onDigitInput,
        onDigitConfirm: () => _zapping.tuneToBufferedChannel(context),
        onTimeshiftSeek: _timeshiftSeek,
      ),
      isLiveMode: _isLiveMode,
      hasZapping: _zapping.hasZapping,
      isRouteActive: route.isCurrent,
    );
  }

  // ── Volume OSD ──
  void _showVolumeOsdBriefly() {
    _volumeOsdTimer?.cancel();
    if (!mounted) return;
    setState(() => _showVolumeOsd = true);
    _volumeOsdTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showVolumeOsd = false);
    });
  }

  // ── EPG loading ──
  Future<void> _loadEpg() async {
    try {
      final channelInfoFuture = _repo.getLiveStreams();
      Map<String, dynamic> data;
      try {
        data = await _repo.getFullDayEpg(widget.streamId!);
      } catch (e, st) {
        AppLogger.warning(LogModule.epg, 'Full-day EPG failed, falling back to short EPG', error: e, stackTrace: st);
        data = await _repo.getShortEpg(widget.streamId!, limit: 30);
      }
      bool catchup = false;
      try {
        final allChannels = await channelInfoFuture;
        final thisChannel = allChannels.where((c) => c.id == widget.streamId).firstOrNull;
        catchup = thisChannel?.hasCatchup ?? false;
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

  /// Re-derive `_epgNow`/`_epgNext`/`_epgNowStart`/`_epgNowEnd`
  /// from the cached `_epgListings` against the wall-clock. Called
  /// from `_epgTickTimer` so the live overlay advances to the next
  /// programme without a fresh network round-trip when the current
  /// one rolls past its end. Mirror of
  /// `_IOSPlayerScreenState._refreshEpgCurrent`.
  void _advanceLiveEpgCurrent() {
    if (_epgListings.isEmpty) return;
    final now = DateTime.now();
    int currentIdx = -1;
    for (var i = 0; i < _epgListings.length; i++) {
      final startTs = int.tryParse(_epgListings[i]['start_ts'] ?? '');
      final endTs = int.tryParse(_epgListings[i]['end_ts'] ?? '');
      if (startTs != null && endTs != null) {
        final s = DateTime.fromMillisecondsSinceEpoch(startTs);
        final e = DateTime.fromMillisecondsSinceEpoch(endTs);
        if (now.isAfter(s) && now.isBefore(e)) {
          currentIdx = i;
          break;
        }
      }
    }
    if (currentIdx >= 0) {
      _epgNow = _epgListings[currentIdx]['title'];
      _epgNext = currentIdx + 1 < _epgListings.length
          ? _epgListings[currentIdx + 1]['title']
          : null;
      final startTs = int.tryParse(_epgListings[currentIdx]['start_ts'] ?? '');
      final endTs = int.tryParse(_epgListings[currentIdx]['end_ts'] ?? '');
      _epgNowStart =
          startTs != null ? DateTime.fromMillisecondsSinceEpoch(startTs) : null;
      _epgNowEnd =
          endTs != null ? DateTime.fromMillisecondsSinceEpoch(endTs) : null;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  bool get _isDesktop => Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  bool get _isLiveMode => widget.streamId != null && !_isCatchupMode && widget.resumeKey == null;
  bool get _isCatchupMode => widget.isCatchup || widget.title.contains('(Replay)');

  // ── Channel zapping (delegated to controller) ──
  void _zapChannel(int delta) => _zapping.zapChannel(delta, context);

  void _returnToLive() {
    if (widget.streamId == null) return;
    final liveUrl = _repo.getLiveStreamUrl(widget.streamId!);
    final liveTitle = widget.title
        .replaceAll('(Replay)', '')
        .replaceFirst(RegExp(r'^.*? \u2014 '), '')
        .trim();
    Navigator.pushReplacement(context, slideRoute(PlayerScreen(
      url: liveUrl,
      title: liveTitle.isEmpty ? AppLocalizations.of(context)!.live : liveTitle,
      streamId: widget.streamId,
    )));
  }

  // \u2500\u2500 Timeshift live \u2500\u2500

  /// Channel currently playing \u2014 looked up from `widget.channelList`
  /// + `widget.channelIndex`. Returns `null` when the player wasn't
  /// launched with a channel context (no zapping \u2192 no timeshift
  /// either).
  Channel? _currentChannel() {
    final list = widget.channelList;
    final idx = widget.channelIndex;
    if (list == null || idx == null || idx < 0 || idx >= list.length) {
      return null;
    }
    return list[idx];
  }

  /// Positive [delta] \u2192 step backward in time (further from live).
  /// Negative \u2192 step toward live. When the new offset reaches 0 we
  /// reload the live HLS URL; otherwise we reload the Xtream
  /// timeshift TS URL anchored at `now - newOffset`. Mirror of
  /// `VLCLivePlayerViewController.timeshiftSeek`.
  void _timeshiftSeek(int delta) {
    if (!mounted || !_isLiveMode) return;
    final channel = _currentChannel();
    if (channel == null || widget.streamId == null) {
      _flashTimeshiftMessage('Replay indisponible', isLive: true);
      return;
    }
    if (!channel.hasCatchup || channel.archiveDays <= 0) {
      _flashTimeshiftMessage('Replay indisponible sur cette cha\u00eene',
          isLive: true);
      return;
    }
    final maxOffsetSec = channel.archiveDays * 24 * 60 * 60;
    final newOffset =
        (_timeshiftOffsetSec + delta).clamp(0, maxOffsetSec);
    if (newOffset == _timeshiftOffsetSec) {
      _flashTimeshiftMessage(
        newOffset == 0
            ? '\u25cf Vous \u00eates en direct'
            : 'Limite du replay atteinte',
        isLive: newOffset == 0,
      );
      return;
    }

    setState(() => _timeshiftOffsetSec = newOffset);

    if (newOffset == 0) {
      _player.open(Media(_repo.getLiveStreamUrl(widget.streamId!)));
      _flashTimeshiftMessage('\u25cf EN DIRECT', isLive: true);
      return;
    }
    final startUtc =
        DateTime.now().toUtc().subtract(Duration(seconds: newOffset));
    // Cover enough forward window so the stream keeps playing toward
    // live without chained reloads. Cap at archive length.
    final bufferMin = (newOffset ~/ 60) + 30;
    final maxMin = (channel.archiveDays * 24 * 60).clamp(60, 1 << 31);
    final durationMin = bufferMin.clamp(30, maxMin);
    final url = _repo.getTimeshiftUrl(
      widget.streamId!,
      startUtc,
      durationMin,
    );
    _player.open(Media(url));
    _flashTimeshiftMessage('\u21a9 ${_formatOffset(newOffset)}', isLive: false);
  }

  void _flashTimeshiftMessage(String msg, {required bool isLive}) {
    if (!mounted) return;
    _timeshiftFlashTimer?.cancel();
    setState(() => _timeshiftFlashMessage = msg);
    _timeshiftFlashTimer = Timer(const Duration(milliseconds: 1500), () {
      // Same guard pattern as the MouseRegion hover handlers across
      // the app — `mounted` alone is not enough because the State is
      // still mounted during the pop animation, but the element is
      // already being deactivated. `route.isCurrent == false` is the
      // canonical signal that we should not call setState.
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      setState(() => _timeshiftFlashMessage = null);
    });
  }

  static String _formatOffset(int sec) {
    if (sec < 60) return '-${sec}s';
    final m = sec ~/ 60;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h > 0) return '-${h}h${mm.toString().padLeft(2, '0')}';
    return '-${m}min';
  }

  /// Show the "More" sheet — secondary playback options that don't
  /// warrant their own button in the drawer's main row (speed, sleep
  /// timer, deinterlace, subtitle style, mini-player). Mirror of the
  /// `onShowMore` action on the tvOS drawer.
  void _showMoreSheet() {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // Pop the More sheet, then defer the secondary action to the
        // next frame so the dismiss animation has time to run before
        // we push another modal. Without that gap, the second sheet
        // occasionally never appears (raced with the More pop) — the
        // subtitle-style picker was the canary case.
        void runAfterDismiss(VoidCallback action) {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            action();
          });
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.speed),
                title: Text(l10n.vitesseLecture),
                subtitle: Text('$_speed×'),
                onTap: () => runAfterDismiss(() {
                  showSpeedPicker(
                    context,
                    currentSpeed: _speed,
                    onSpeedChanged: (v) {
                      _player.setRate(v);
                      setState(() => _speed = v);
                    },
                  );
                }),
              ),
              ListTile(
                leading: Icon(
                  Icons.timer,
                  color: _sleepRemaining != null ? Colors.amber : null,
                ),
                title: Text(_sleepRemaining != null
                    ? l10n.veilleActive(_sleepRemaining!.inMinutes)
                    : l10n.minuterieVeille),
                onTap: () => runAfterDismiss(() {
                  showSleepTimerPicker(
                    context,
                    sleepRemaining: _sleepRemaining,
                    onCancel: _cancelSleepTimer,
                    onStart: _startSleepTimer,
                  );
                }),
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.deblur,
                  color: _deinterlace ? AppColors.primaryBlue : null,
                ),
                title: Text(l10n.desentrelacement),
                value: _deinterlace,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (_) {
                  _toggleDeinterlace();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.subtitles),
                title: Text(l10n.styleSousTitres),
                onTap: () => runAfterDismiss(_onSubtitleStylePicker),
              ),
              ListTile(
                leading: const Icon(Icons.picture_in_picture_alt),
                title: Text(l10n.miniPlayer),
                onTap: () => runAfterDismiss(_minimize),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Controls builder — Apple-TV+-style drawer (cf.
  /// [`CinematicControls`](widgets/cinematic_controls.dart)).
  ///
  /// `MaterialVideoControlsTheme` further down still wraps the [Video]
  /// widget defensively, but [CinematicControls] is what's actually
  /// rendered: gradient drawer, monospace time readout, capsule scrub
  /// bar, round transport buttons, secondary cluster (audio / subs /
  /// aspect / more). The slimmed-down [PlayerAppBar] at the top now
  /// only carries channel-context badges + zap shortcuts.
  Widget _buildVideoControls(VideoState state) {
    // Live overlay payload — mirror of iOS / tvOS top-left dense
    // block. All four fields are optional and gracefully degrade if
    // EPG hasn't loaded yet (channel name + LIVE pill still show).
    String? channelLabel;
    if (widget.channelList != null && widget.channelIndex != null) {
      channelLabel =
          'Chaîne ${widget.channelIndex! + 1} / ${widget.channelList!.length}';
    }
    String? epgTimeRange;
    if (_isLiveMode && _epgNowStart != null && _epgNowEnd != null) {
      String hm(DateTime dt) =>
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      epgTimeRange = '${hm(_epgNowStart!)} → ${hm(_epgNowEnd!)}';
    }
    double? liveEpgProgress;
    if (_isLiveMode && _epgNowStart != null && _epgNowEnd != null) {
      final total = _epgNowEnd!.difference(_epgNowStart!).inSeconds;
      if (total > 0) {
        liveEpgProgress = DateTime.now()
            .difference(_epgNowStart!)
            .inSeconds
            .clamp(0, total)
            .toDouble() /
            total;
      }
    }

    return Builder(builder: (ctx) {
      _videoCtx = ctx;
      return CinematicControls(
        player: _player,
        title: widget.title,
        isLiveMode: _isLiveMode,
        hasMultipleAudioTracks: _audioTracks.length >= 2,
        hasSubtitleTracks: _subtitleTracks.isNotEmpty,
        aspectRatioLabel: _aspectRatioLabel,
        epgNowTitle: _isLiveMode ? _epgNow : null,
        epgNext: _isLiveMode ? _epgNext : null,
        epgTimeRange: epgTimeRange,
        epgProgress: liveEpgProgress,
        channelLabel: _isLiveMode ? channelLabel : null,
        onShowAudioPicker: _audioTracks.length >= 2
            ? () => showTrackPicker(
                  context,
                  player: _player,
                  audioTracks: _audioTracks,
                  subtitleTracks: _subtitleTracks,
                  initialTab: 0,
                )
            : null,
        onShowSubtitlePicker: _subtitleTracks.isNotEmpty
            ? () => showTrackPicker(
                  context,
                  player: _player,
                  audioTracks: _audioTracks,
                  subtitleTracks: _subtitleTracks,
                  initialTab: 1,
                )
            : null,
        onCycleAspect: _cycleAspectRatio,
        onMore: _showMoreSheet,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: PlayerAppBar(
        title: widget.title,
        epgNow: _epgNow,
        epgNext: _epgNext,
        epgProgress: epgProgress,
        isCatchupMode: _isCatchupMode,
        isLiveMode: _isLiveMode,
        streamId: widget.streamId,
        channelList: _zapping.hasZapping,
        qualityBadge: _qualityBadge,
        bitrate: _bitrate,
        epgListings: _epgListings,
        catchupSupported: _catchupSupported,
        onReturnToLive: _returnToLive,
        onZapChannel: _zapChannel,
        hlsVariants: _hlsVariants,
        activeVariantUrl: _activeVariantUrl,
        onVariantSelected: _selectVariant,
        repo: _repo,
      ),
      body: Stack(children: [
        MaterialVideoControlsTheme(
          normal: MaterialVideoControlsThemeData(
            seekBarMargin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            bottomButtonBarMargin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            // On desktop: disable touch gestures, show controls on hover.
            // NOTE: Predidit's media_kit fork drops `volumeGesture` /
            // `brightnessGesture` (those were upstream 1.2.x-only). We
            // already passed `!_isDesktop` → `false` on every platform
            // we ship today, so the removal is a no-op behavior-wise.
            seekGesture: !_isDesktop,
            seekOnDoubleTap: !_isDesktop,
            visibleOnMount: true,
            controlsHoverDuration: const Duration(seconds: 3),
          ),
          fullscreen: MaterialVideoControlsThemeData(
            topButtonBar: const [_FullscreenBackButton(), Spacer()],
            seekBarMargin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            bottomButtonBarMargin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            seekGesture: !_isDesktop,
            seekOnDoubleTap: !_isDesktop,
          ),
          child: SizedBox.expand(
            child: Video(
              controller: _controller,
              controls: _buildVideoControls,
              fit: BoxFit.contain,
              fill: Colors.black,
              // Subtitles are rendered by media_kit as a Flutter widget,
              // not by libmpv — so the historical `np.setProperty('sub-*')`
              // calls in `_applySubtitleSettings` are silently no-ops.
              // The user-controlled style flows through here instead, and
              // a `setState` rebuild propagates updates live.
              subtitleViewConfiguration: SubtitleViewConfiguration(
                style: TextStyle(
                  fontSize: _subtitleFontSize,
                  color: _subtitleColor,
                  backgroundColor: Colors.black
                      .withValues(alpha: _subtitleBgOpacity),
                  fontWeight: FontWeight.w600,
                  shadows: const <Shadow>[
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                  style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.retour),
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
        // Connectivity banner
        if (_showConnectivityBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _connectivityStatus == ConnectivityStatus.online
                  ? Colors.green.withValues(alpha: 0.85)
                  : _connectivityStatus == ConnectivityStatus.reconnecting
                  ? Colors.orange.withValues(alpha: 0.85)
                  : Colors.red.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _connectivityStatus == ConnectivityStatus.online
                        ? Icons.cloud_done
                        : _connectivityStatus == ConnectivityStatus.reconnecting
                        ? Icons.sync
                        : Icons.cloud_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connectivityStatus == ConnectivityStatus.online
                        ? 'Connexion r\u00e9tablie'
                        : _connectivityStatus == ConnectivityStatus.reconnecting
                        ? 'Reconnexion\u2026'
                        : 'Connexion perdue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Volume OSD
        if (_showVolumeOsd)
          VolumeOsd(volume: _player.state.volume),
        // Timeshift OSD (live ←/→)
        if (_timeshiftFlashMessage != null)
          TimeshiftOsd(
            message: _timeshiftFlashMessage!,
            isLive: _timeshiftOffsetSec == 0,
          ),
        // Channel number OSD
        if (_zapping.digitBuffer.isNotEmpty)
          ChannelNumberOsd(digits: _zapping.digitBuffer),
        // Channel list overlay
        if (_zapping.showChannelList && widget.channelList != null && widget.channelIndex != null)
          ChannelListOverlay(
            channels: widget.channelList!,
            currentIndex: widget.channelIndex!,
            onSelect: (idx) {
              _zapping.closeChannelList();
              if (idx != widget.channelIndex) _zapping.zapToIndex(idx, context);
            },
            onClose: _zapping.closeChannelList,
          ),
      ]),
    );
  }
}
