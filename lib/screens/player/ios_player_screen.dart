import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import '../../core/colors.dart';
import '../../core/logger.dart';
import '../../models/channel.dart';
import '../../models/next_episode_info.dart';
import '../../repositories/content_repository.dart';
import '../../services/watch_progress.dart';

/// iOS / iPadOS video player backed by `flutter_vlc_player` (libVLC).
///
/// AVPlayer (video_player) refuses MKV / AVI / many codecs the IPTV provider
/// streams, and media_kit (libmpv) crashes at init on iOS. libVLC handles
/// everything we throw at it.
///
/// API mirrors the cross-platform `PlayerScreen` so call sites don't change:
/// the wrapping facade picks the right impl at build time.
class IOSPlayerScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final String? streamId;
  final String? resumeKey;
  final String? coverUrl;
  final NextEpisodeInfo? nextEpisode;
  final bool isCatchup;
  final List<Channel>? channelList;
  final int? channelIndex;

  const IOSPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.streamId,
    this.resumeKey,
    this.coverUrl,
    this.nextEpisode,
    this.isCatchup = false,
    this.channelList,
    this.channelIndex,
  });

  @override
  ConsumerState<IOSPlayerScreen> createState() => _IOSPlayerScreenState();
}

class _IOSPlayerScreenState extends ConsumerState<IOSPlayerScreen> {
  VlcPlayerController? _controller;
  bool _showControls = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _resumed = false;
  // True once the stream has started rendering at least one frame. Until then
  // we keep the loading overlay (with a back button) on top so the user is
  // never stranded staring at a spinner with no escape.
  bool _hasStartedPlaying = false;

  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Timer? _connectTimeoutTimer;
  Timer? _epgTickTimer;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;
  static const _connectTimeout = Duration(seconds: 25);

  // ── EPG state (live mode only) ─────────────────────────────────────
  // Mirrors the cross-platform `PlayerScreen` so the iOS overlay shows
  // the same channel context: current programme title, next programme,
  // and a thin progress bar of the current programme.
  String? _epgNow;
  String? _epgNext;
  DateTime? _epgNowStart;
  DateTime? _epgNowEnd;
  List<Map<String, String>> _epgListings = const [];

  bool get _isLiveMode => widget.streamId != null && !widget.isCatchup;

  // Diagnostics surfaced in the loading overlay so we can see exactly where
  // VLC is stuck on real devices (no easy way to read flutter logs there).
  PlayingState? _lastLoggedState;
  String _diagState = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initPlayer();
    if (_isLiveMode) {
      _loadEpg();
      // Re-tick every 30 s — recomputes the progress bar (which is
      // derived from DateTime.now()) and advances to the next
      // programme once the current one ends. Cheap rebuild scoped to
      // the overlay; the platform view doesn't repaint.
      _epgTickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        _advanceEpgIfNeeded();
      });
    }
  }

  void _initPlayer() {
    // Options mirror the flutter_vlc_player example for IPTV-style streams:
    // hardware decoding, network caching to absorb jitter, and HTTP reconnect
    // so transient drops don't kill playback.
    final c = VlcPlayerController.network(
      widget.url,
      hwAcc: HwAcc.full,
      autoPlay: true,
      // Subtitle sizing (`--freetype-rel-fontsize=20`) lives in our
      // vendored fork at `packages/flutter_vlc_player/ios/Classes/
      // VlcViewController.swift` because it's a libvlc-instance option
      // that has to reach `VLCMediaPlayer(options:)` — the upstream plugin
      // only forwards options through `media.addOption(...)`, where they
      // are silently ignored.
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
      ),
    );
    _controller = c;
    c.addListener(_onPlayerTick);
    // Some streams don't autoplay reliably; force play once the platform
    // view is ready.
    c.addOnInitListener(() async {
      try {
        await c.play();
      } catch (_) {/* ignore — listener will surface real errors */}
    });

    // Save every 30s — see player_screen.dart for the long story (the
    // chained SharedPreferences writes inside WatchProgress.save can
    // pre-empt the rendering microtask and drop a frame, producing a
    // visible image stutter every 5s on slower disks).
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.resumeKey != null && _lastDur > Duration.zero) {
        WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
      }
    });

    // If the stream hasn't started after 25 s, surface a clear error instead
    // of leaving the user stuck on a spinner with no back affordance.
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (!mounted || _hasStartedPlaying || _hasError) return;
      setState(() {
        _hasError = true;
        _errorMessage =
            'La chaîne ne répond pas. Vérifie ta connexion ou essaie une autre source.';
      });
    });
  }

  Future<void> _onPlayerTick() async {
    final c = _controller;
    if (c == null) return;
    final v = c.value;

    // Once initialized for the first time, jump to the saved position (VOD).
    if (!_resumed && v.isInitialized && widget.resumeKey != null) {
      _resumed = true;
      final savedPos = await WatchProgress.getPosition(widget.resumeKey!);
      if (savedPos != null &&
          savedPos.inSeconds > 5 &&
          v.duration > Duration.zero &&
          savedPos < v.duration - const Duration(seconds: 5)) {
        await c.seekTo(savedPos);
      }
    }

    _lastPos = v.position;
    _lastDur = v.duration;

    // Log + surface VLC state transitions so we can debug stuck streams.
    if (v.playingState != _lastLoggedState) {
      _lastLoggedState = v.playingState;
      AppLogger.info(LogModule.player,
          'VLC state=${v.playingState.name} '
          'isInit=${v.isInitialized} '
          'isPlaying=${v.isPlaying} '
          'isBuffering=${v.isBuffering} '
          'size=${v.size} '
          'pos=${v.position.inMilliseconds}ms '
          'err=${v.errorDescription}');
      if (kDebugMode) {
        // Direct print for `flutter run` console clarity.
        // ignore: avoid_print
        print('[VLC] state=${v.playingState.name} init=${v.isInitialized} '
            'playing=${v.isPlaying} buf=${v.isBuffering} '
            'size=${v.size} err=${v.errorDescription}');
      }
    }
    _diagState = v.playingState.name;

    // First sign that VLC is past the connection phase: any of these means
    // we should hand the screen over to the player and stop covering it
    // with our loading overlay. We accept `isInitialized` as an early
    // fallback — if VLC's media events never reach us, we'd otherwise sit
    // on a perma-loading overlay forever.
    final isStarting = v.isPlaying ||
        v.isBuffering ||
        v.position > Duration.zero ||
        v.size != Size.zero ||
        v.playingState == PlayingState.playing ||
        v.playingState == PlayingState.buffering ||
        v.isInitialized;
    if (!_hasStartedPlaying && isStarting) {
      _hasStartedPlaying = true;
      _connectTimeoutTimer?.cancel();
      _scheduleHideControls();
    }

    if (v.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = v.errorDescription.isEmpty
            ? 'Erreur de lecture'
            : v.errorDescription;
      });
    } else if (mounted) {
      // Trigger rebuild for play/pause icon + progress bar updates.
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    _scheduleHideControls();
  }

  void _seekRelative(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final newPos = c.value.position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (c.value.duration > Duration.zero && newPos > c.value.duration
            ? c.value.duration
            : newPos);
    c.seekTo(clamped);
    _scheduleHideControls();
  }

  @override
  void dispose() {
    if (widget.resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
    }
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _connectTimeoutTimer?.cancel();
    _epgTickTimer?.cancel();
    final c = _controller;
    if (c != null) {
      c.removeListener(_onPlayerTick);
      // VLC needs an explicit stop before disposal. Both calls can throw a
      // LateInitializationError on `_viewId` when the platform view never
      // got created (user bailed mid-init, or controller was just recreated
      // by _changeSubtitleScale and the screen was unmounted before the new
      // platform view mounted) — swallow it.
      try { c.stop(); } catch (_) {}
      try { c.dispose(); } catch (_) {}
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      // No outer GestureDetector — VLC's native UIView swallows taps before
      // they reach an ancestor. Instead we put a transparent tap-catcher
      // ABOVE the platform view inside the Stack so taps are caught in
      // Flutter first.
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (c != null)
            Center(
              child: VlcPlayer(
                controller: c,
                aspectRatio: _aspectRatio(c),
                // Our own loading overlay handles the "Connexion…" UI;
                // VLC's built-in spinner would make it a double spinner.
                placeholder: const SizedBox.shrink(),
              ),
            ),

          // Transparent layer above the platform view that catches taps
          // and toggles the controls. Without this, the iOS UIView
          // consumes every touch and the user has no way to bring the
          // controls (or back button) back.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),

          if (_hasError) _buildError(),

          // While the stream is buffering / connecting, force-show a
          // loading overlay with a back button so the user is never stuck
          // staring at a spinner with no escape.
          if (!_hasStartedPlaying && !_hasError) _buildLoadingOverlay(),

          if (_showControls && c != null && !_hasError && _hasStartedPlaying)
            _buildControls(c),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _diagState.isEmpty ? 'Connexion…' : 'Connexion… ($_diagState)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _aspectRatio(VlcPlayerController c) {
    final size = c.value.size;
    if (size.width <= 0 || size.height <= 0) return 16 / 9;
    return size.width / size.height;
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 12),
            const Text('Lecture impossible',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(VlcPlayerController c) {
    final v = c.value;
    // Tap on the controls' background (anywhere not on a button) hides
    // them — same affordance as tapping the video itself when controls
    // are off. IconButton children still receive their own taps.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                // Live mode with EPG: stack channel name + current
                // programme as a two-line title. Mirror of the
                // cross-platform `PlayerAppBar` (which uses a
                // similar Column for the title widget when `epgNow`
                // is non-null).
                child: _epgNow != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _epgNow!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11),
                          ),
                        ],
                      )
                    : Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Options',
                onPressed: () => _openOptionsSheet(c),
              ),
            ]),
            // Thin EPG progress bar just under the top row — sits
            // where the VOD slider would be, but for live it tracks
            // the current programme's wall-clock progress instead.
            if (_isLiveMode && _epgProgress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: _epgProgress,
                    backgroundColor: Colors.white12,
                    color: AppColors.primaryBlue,
                    minHeight: 3,
                  ),
                ),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () => _seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                    v.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.forward_30, color: Colors.white),
                  onPressed: () => _seekRelative(const Duration(seconds: 30)),
                ),
              ],
            ),
            const Spacer(),
            // Live mode footer: "Suivant: X · HH:mm → HH:mm" hint
            // when we have both current + next EPG data. Sits where
            // the VOD slider would be — they're mutually exclusive
            // because live has no `v.duration`.
            if (_isLiveMode &&
                v.duration <= Duration.zero &&
                (_epgNow != null || _epgNext != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  children: [
                    if (_epgNowStart != null && _epgNowEnd != null) ...[
                      Text(
                        '${_fmtHm(_epgNowStart!)} → ${_fmtHm(_epgNowEnd!)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (_epgNext != null)
                      Expanded(
                        child: Text(
                          'Suivant : $_epgNext',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            if (v.duration > Duration.zero) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primaryBlue,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primaryBlue,
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: v.position.inMilliseconds
                        .clamp(0, v.duration.inMilliseconds)
                        .toDouble(),
                    min: 0,
                    max: v.duration.inMilliseconds.toDouble(),
                    onChanged: widget.isCatchup
                        ? null
                        : (val) => c.seekTo(
                            Duration(milliseconds: val.toInt())),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(v.position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    Text(_fmt(v.duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── EPG ──────────────────────────────────────────────────────────────
  // Mirror of `PlayerScreen._loadEpg` (cross-platform). We pull the
  // full-day EPG for the current channel, fall back to the short EPG
  // (limit: 30) if the full-day endpoint errors, decode base64 titles
  // and figure out which programme is "now" by wall-clock comparison.
  // The progress bar is computed each frame in `_buildControls` from
  // `_epgNowStart` / `_epgNowEnd`; `_epgTickTimer` (set in initState)
  // forces a 30 s rebuild and advances to the next programme.
  Future<void> _loadEpg() async {
    if (widget.streamId == null) return;
    try {
      final repo = ref.read(contentRepositoryProvider);
      Map<String, dynamic> data;
      try {
        data = await repo.getFullDayEpg(widget.streamId!);
      } catch (e, st) {
        AppLogger.warning(
          LogModule.epg,
          'iOS: full-day EPG failed, falling back to short EPG',
          error: e,
          stackTrace: st,
        );
        data = await repo.getShortEpg(widget.streamId!, limit: 30);
      }
      final listings = data['epg_listings'] as List?;
      if (listings == null || listings.isEmpty) return;

      String dec(String s) {
        if (s.isEmpty) return s;
        try {
          return utf8.decode(base64.decode(s));
        } catch (_) {
          return s;
        }
      }

      DateTime? parseTs(dynamic v) {
        if (v == null) return null;
        final n = int.tryParse(v.toString());
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        return null;
      }

      final allProgs = listings.map<Map<String, String>>((e) {
        final start = parseTs(e['start_timestamp'] ?? e['start']);
        final end = parseTs(e['stop_timestamp'] ?? e['stop']);
        return {
          'title': dec((e['title'] ?? '').toString()),
          'start_ts': start?.millisecondsSinceEpoch.toString() ?? '',
          'end_ts': end?.millisecondsSinceEpoch.toString() ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _epgListings = allProgs;
        _refreshEpgCurrent();
      });
    } catch (e, st) {
      AppLogger.warning(
        LogModule.player,
        'iOS: failed to load EPG data',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Re-evaluate which programme is "now" based on wall-clock + the
  /// cached `_epgListings`. No-op if the listings haven't loaded yet.
  void _refreshEpgCurrent() {
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
    } else {
      _epgNow = null;
      _epgNext = null;
      _epgNowStart = null;
      _epgNowEnd = null;
    }
  }

  /// Called by the 30 s tick timer. Re-derives the current programme
  /// + triggers a rebuild so the progress bar advances. When the
  /// current programme has rolled past its end, the next one slides
  /// into "now" automatically without another network round-trip.
  void _advanceEpgIfNeeded() {
    if (_epgListings.isEmpty) return;
    setState(() => _refreshEpgCurrent());
  }

  /// EPG progress \[0..1\] of the current programme, or null when we
  /// don't have a current programme bounds.
  double? get _epgProgress {
    final s = _epgNowStart;
    final e = _epgNowEnd;
    if (s == null || e == null) return null;
    final total = e.difference(s).inSeconds;
    if (total <= 0) return null;
    final elapsed = DateTime.now().difference(s).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Future<void> _openOptionsSheet(VlcPlayerController c) async {
    _hideControlsTimer?.cancel();
    Map<int, String> audioTracks = const {};
    Map<int, String> spuTracks = const {};
    int? activeAudio;
    int? activeSpu;
    double speed = c.value.playbackSpeed;
    try {
      audioTracks = await c.getAudioTracks();
      spuTracks = await c.getSpuTracks();
      activeAudio = await c.getAudioTrack();
      activeSpu = await c.getSpuTrack();
    } catch (_) {/* leave empty maps; sheet still shows speed picker */}
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Widget section(String title, Widget child) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    child,
                  ],
                ),
              );

          Widget tile(String label, bool selected, VoidCallback onTap) =>
              ListTile(
                dense: true,
                title: Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal)),
                trailing: selected
                    ? const Icon(Icons.check,
                        color: AppColors.primaryBlue, size: 18)
                    : null,
                onTap: onTap,
              );

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (audioTracks.isNotEmpty)
                    section('Audio', Column(
                      children: audioTracks.entries
                          .map((e) => tile(e.value, activeAudio == e.key,
                              () async {
                            await c.setAudioTrack(e.key);
                            setSheetState(() => activeAudio = e.key);
                          }))
                          .toList(),
                    )),
                  if (spuTracks.isNotEmpty)
                    section('Sous-titres', Column(
                      children: [
                        tile('Désactivés', activeSpu == -1 || activeSpu == 0,
                            () async {
                          await c.setSpuTrack(-1);
                          setSheetState(() => activeSpu = -1);
                        }),
                        ...spuTracks.entries.where((e) => e.key > 0).map(
                            (e) => tile(e.value, activeSpu == e.key,
                                () async {
                              await c.setSpuTrack(e.key);
                              setSheetState(() => activeSpu = e.key);
                            })),
                      ],
                    )),
                  section('Vitesse', Wrap(
                    spacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        .map((s) => ChoiceChip(
                              label: Text('$s×'),
                              selected: (speed - s).abs() < 0.01,
                              labelStyle: TextStyle(
                                  color: (speed - s).abs() < 0.01
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13),
                              backgroundColor: Colors.white12,
                              selectedColor: AppColors.primaryBlue,
                              onSelected: (_) async {
                                await c.setPlaybackSpeed(s);
                                setSheetState(() => speed = s);
                              },
                            ))
                        .toList(),
                  )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
    if (mounted) _scheduleHideControls();
  }
}
