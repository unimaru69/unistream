import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/colors.dart';
import '../../models/channel.dart';
import '../../models/next_episode_info.dart';
import '../../services/watch_progress.dart';

/// iOS / iPadOS video player backed by `video_player` (AVPlayer).
///
/// Replaces media_kit on Apple mobile platforms — libmpv crashes at init on
/// iOS so we cannot use it. AVPlayer handles HLS / mp4 / fmp4 natively and
/// is well integrated with the system (PiP, AirPlay, lock screen).
///
/// API mirrors the cross-platform `PlayerScreen` so call sites don't change:
/// the wrapping facade picks the right impl at build time.
class IOSPlayerScreen extends StatefulWidget {
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
  State<IOSPlayerScreen> createState() => _IOSPlayerScreenState();
}

class _IOSPlayerScreenState extends State<IOSPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _hasError = false;
  String? _errorMessage;

  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;

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
  }

  Future<void> _initPlayer() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = c;
      await c.initialize();

      // Resume from saved position for VOD / episodes.
      if (widget.resumeKey != null) {
        final savedPos = await WatchProgress.getPosition(widget.resumeKey!);
        if (savedPos != null && savedPos.inSeconds > 5 &&
            savedPos < c.value.duration - const Duration(seconds: 5)) {
          await c.seekTo(savedPos);
        }
      }

      c.addListener(_onPlayerTick);
      await c.play();

      _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (widget.resumeKey != null && _lastDur > Duration.zero) {
          WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
        }
      });

      _scheduleHideControls();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onPlayerTick() {
    final c = _controller;
    if (c == null) return;
    _lastPos = c.value.position;
    _lastDur = c.value.duration;
    if (c.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = c.value.errorDescription ?? 'Erreur de lecture';
      });
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
    setState(() {});
    _scheduleHideControls();
  }

  void _seekRelative(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final newPos = c.value.position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > c.value.duration ? c.value.duration : newPos);
    c.seekTo(clamped);
    _scheduleHideControls();
  }

  @override
  void dispose() {
    // Persist final position before tearing down.
    if (widget.resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(widget.resumeKey!, _lastPos, _lastDur);
    }
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _controller?.removeListener(_onPlayerTick);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else if (_hasError)
              _buildError()
            else
              const Center(child: CircularProgressIndicator()),

            if (_showControls && c != null && c.value.isInitialized) _buildControls(c),
          ],
        ),
      ),
    );
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

  Widget _buildControls(VideoPlayerController c) {
    return Container(
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
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const Spacer(),
            // Center play/pause + skip controls.
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
                    c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
            // Progress bar (only meaningful for VOD; live HLS has duration too
            // but seeking to the past is rarely allowed).
            if (c.value.duration > Duration.zero) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: !widget.isCatchup,
                  colors: VideoProgressColors(
                    playedColor: AppColors.primaryBlue,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(c.value.position),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_fmt(c.value.duration),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
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
}
