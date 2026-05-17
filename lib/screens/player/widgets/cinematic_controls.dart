import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';
import '../../../utils/title_formatting.dart';

/// Apple-TV+-style player drawer. Mirror of
/// `tvos/.../Player/VLCVODOverlayView.swift`:
/// - bottom drawer with a clear → black gradient background
/// - title + monospace time readout in the header
/// - capsule scrub bar with an accent fill and a white scrub head
/// - cluster of round transport buttons (−15 s / play-pause / +30 s)
/// - secondary cluster (audio / subs / aspect / more) when available
///
/// Replaces media_kit's `MaterialVideoControls` for VOD / catch-up
/// playback. Live-mode hides the scrub + skip cluster (no seek), and
/// the secondary cluster shrinks to the buttons that actually have
/// a choice (audio only when ≥2 tracks, subs only when at least one).
///
/// Auto-hide kicks in after [autoHideAfter] of pointer / keyboard
/// inactivity while the player is actually playing — paused state
/// keeps the drawer pinned, matching every desktop video player the
/// user already knows. A pointer move or any tap reveals the drawer
/// again.
class CinematicControls extends StatefulWidget {
  const CinematicControls({
    super.key,
    required this.player,
    required this.title,
    this.subtitle,
    this.isLiveMode = false,
    this.hasMultipleAudioTracks = false,
    this.hasSubtitleTracks = false,
    this.aspectRatioLabel = 'Auto',
    this.onShowAudioPicker,
    this.onShowSubtitlePicker,
    this.onCycleAspect,
    this.onMore,
    this.autoHideAfter = const Duration(seconds: 3),
    this.epgNowTitle,
    this.epgNext,
    this.epgTimeRange,
    this.epgProgress,
    this.channelLabel,
  });

  final Player player;
  final String title;
  final String? subtitle;
  final bool isLiveMode;
  final bool hasMultipleAudioTracks;
  final bool hasSubtitleTracks;
  final String aspectRatioLabel;
  final VoidCallback? onShowAudioPicker;
  final VoidCallback? onShowSubtitlePicker;
  final VoidCallback? onCycleAspect;
  final VoidCallback? onMore;
  final Duration autoHideAfter;

  // ── Live overlay (top-left dense info block, tvOS-style) ─────────
  // Optional EPG strip rendered above the drawer when [isLiveMode] is
  // true AND the drawer is visible. Mirrors the iOS
  // `IOSPlayerScreen._buildLiveControls` block so the two platforms
  // feel identical. All four fields are independent — partial data
  // gracefully degrades (e.g. no progress when [epgProgress] is null).
  final String? epgNowTitle;
  final String? epgNext;
  /// Already-formatted "HH:mm → HH:mm" range. Caller does the parse
  /// so we keep this widget free of date-time logic.
  final String? epgTimeRange;
  /// 0..1 of the current programme's wall-clock progress.
  final double? epgProgress;
  /// "Chaîne X / Y" — caller-formatted (the channel list lives in
  /// the parent state, not here).
  final String? channelLabel;

  @override
  State<CinematicControls> createState() => _CinematicControlsState();
}

class _CinematicControlsState extends State<CinematicControls> {
  bool _drawerVisible = true;
  Timer? _hideTimer;

  /// Set while the user is dragging the scrub head — overrides the
  /// player's reported position so the bar follows the pointer
  /// instead of jittering between drag updates and the player's
  /// next position tick.
  Duration? _scrubPosition;
  StreamSubscription<bool>? _playingSub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playing = widget.player.state.playing;
    _playingSub = widget.player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      // Pin the drawer when paused; resume the auto-hide schedule
      // when playback restarts.
      if (p) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        if (!_drawerVisible) setState(() => _drawerVisible = true);
      }
    });
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(widget.autoHideAfter, () {
      if (!mounted) return;
      // Don't snap the drawer away from a user mid-scrub.
      if (_scrubPosition != null) return;
      setState(() => _drawerVisible = false);
    });
  }

  void _onUserActivity() {
    if (!_drawerVisible) {
      setState(() => _drawerVisible = true);
    }
    _scheduleHide();
  }

  void _togglePlay() {
    widget.player.playOrPause();
    _onUserActivity();
  }

  void _seekRelative(int seconds) {
    final cur = widget.player.state.position;
    final dur = widget.player.state.duration;
    var target = cur + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    widget.player.seek(target);
    _onUserActivity();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _onUserActivity(),
      onEnter: (_) => _onUserActivity(),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Click anywhere on the video to toggle play/pause and reveal
          // the drawer (matches every desktop video player). Behind the
          // drawer so its taps win when both are visible.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _togglePlay,
            ),
          ),

          // ── Live overlay (top-left) ──
          // Mirror of tvOS VLCLivePlayerViewController's left dense
          // block, ported from iOS player. Shows only when we're in
          // live mode AND the drawer is visible (same visibility as
          // the rest of the chrome — they share the auto-hide).
          if (widget.isLiveMode)
            AnimatedPositioned(
              duration: DS.motion.standard,
              curve: DS.motion.curve,
              left: _drawerVisible ? 24 : -360,
              top: 24,
              child: AnimatedOpacity(
                duration: DS.motion.standard,
                curve: DS.motion.curve,
                opacity: _drawerVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  child: _LiveOverlay(
                    title: widget.title,
                    channelLabel: widget.channelLabel,
                    epgNowTitle: widget.epgNowTitle,
                    epgNext: widget.epgNext,
                    epgTimeRange: widget.epgTimeRange,
                    epgProgress: widget.epgProgress,
                  ),
                ),
              ),
            ),

          AnimatedPositioned(
            duration: DS.motion.standard,
            curve: DS.motion.curve,
            left: 0,
            right: 0,
            bottom: _drawerVisible ? 0 : -260,
            child: AnimatedOpacity(
              duration: DS.motion.standard,
              curve: DS.motion.curve,
              opacity: _drawerVisible ? 1.0 : 0.0,
              child: _Drawer(
                player: widget.player,
                title: widget.title,
                subtitle: widget.subtitle,
                isLiveMode: widget.isLiveMode,
                playing: _playing,
                scrubPosition: _scrubPosition,
                hasMultipleAudioTracks: widget.hasMultipleAudioTracks,
                hasSubtitleTracks: widget.hasSubtitleTracks,
                aspectRatioLabel: widget.aspectRatioLabel,
                onTogglePlay: _togglePlay,
                onSeekRelative: _seekRelative,
                onScrubStart: (pos) {
                  setState(() => _scrubPosition = pos);
                  _hideTimer?.cancel();
                },
                onScrubUpdate: (pos) {
                  setState(() => _scrubPosition = pos);
                },
                onScrubEnd: (pos) {
                  widget.player.seek(pos);
                  setState(() => _scrubPosition = null);
                  _scheduleHide();
                },
                onShowAudioPicker: widget.onShowAudioPicker,
                onShowSubtitlePicker: widget.onShowSubtitlePicker,
                onCycleAspect: widget.onCycleAspect,
                onMore: widget.onMore,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({
    required this.player,
    required this.title,
    required this.subtitle,
    required this.isLiveMode,
    required this.playing,
    required this.scrubPosition,
    required this.hasMultipleAudioTracks,
    required this.hasSubtitleTracks,
    required this.aspectRatioLabel,
    required this.onTogglePlay,
    required this.onSeekRelative,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onShowAudioPicker,
    required this.onShowSubtitlePicker,
    required this.onCycleAspect,
    required this.onMore,
  });

  final Player player;
  final String title;
  final String? subtitle;
  final bool isLiveMode;
  final bool playing;
  final Duration? scrubPosition;
  final bool hasMultipleAudioTracks;
  final bool hasSubtitleTracks;
  final String aspectRatioLabel;
  final VoidCallback onTogglePlay;
  final void Function(int seconds) onSeekRelative;
  final void Function(Duration) onScrubStart;
  final void Function(Duration) onScrubUpdate;
  final void Function(Duration) onScrubEnd;
  final VoidCallback? onShowAudioPicker;
  final VoidCallback? onShowSubtitlePicker;
  final VoidCallback? onCycleAspect;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Color(0xD9000000), // black @ 85 %
            Color(0xF2000000), // black @ 95 %
          ],
          stops: <double>[0.0, 0.45, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DS.padding.screenHorizontal,
          DS.space.xl,
          DS.padding.screenHorizontal,
          DS.space.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Header(
              title: title,
              subtitle: subtitle,
              isLiveMode: isLiveMode,
              player: player,
              scrubPosition: scrubPosition,
            ),
            SizedBox(height: DS.space.lg),
            if (!isLiveMode)
              _ScrubBar(
                player: player,
                scrubPosition: scrubPosition,
                onScrubStart: onScrubStart,
                onScrubUpdate: onScrubUpdate,
                onScrubEnd: onScrubEnd,
              ),
            if (!isLiveMode) SizedBox(height: DS.space.lg),
            _ButtonRow(
              isLiveMode: isLiveMode,
              playing: playing,
              hasMultipleAudioTracks: hasMultipleAudioTracks,
              hasSubtitleTracks: hasSubtitleTracks,
              aspectRatioLabel: aspectRatioLabel,
              onTogglePlay: onTogglePlay,
              onSeekRelative: onSeekRelative,
              onShowAudioPicker: onShowAudioPicker,
              onShowSubtitlePicker: onShowSubtitlePicker,
              onCycleAspect: onCycleAspect,
              onMore: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.isLiveMode,
    required this.player,
    required this.scrubPosition,
  });

  final String title;
  final String? subtitle;
  final bool isLiveMode;
  final Player player;
  final Duration? scrubPosition;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.cleanedTitleNoYear,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DSText.title2.copyWith(color: Colors.white),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                SizedBox(height: DS.space.xxs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.body.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isLiveMode) ...<Widget>[
          SizedBox(width: DS.space.md),
          _TimeReadout(player: player, scrubPosition: scrubPosition),
        ] else
          const _LiveBadge(),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DS.space.sm,
        vertical: DS.space.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentWarm,
        borderRadius: BorderRadius.circular(DS.radius.tag),
      ),
      child: Text(
        'LIVE',
        style: DSText.label.copyWith(color: Colors.white),
      ),
    );
  }
}

class _TimeReadout extends StatelessWidget {
  const _TimeReadout({required this.player, required this.scrubPosition});

  final Player player;
  final Duration? scrubPosition;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (_, posSnap) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (_, durSnap) {
            final pos = scrubPosition ?? posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            return Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: _fmt(pos),
                    style: DSText.body.copyWith(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '  /  ',
                    style: DSText.body.copyWith(
                      color: DS.colour.textTertiary,
                    ),
                  ),
                  TextSpan(
                    text: _fmt(dur),
                    style: DSText.body.copyWith(
                      color: DS.colour.textSecondary,
                      fontFamily: 'monospace',
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final total = d.inSeconds;
    if (total < 0) return '--:--';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

class _ScrubBar extends StatelessWidget {
  const _ScrubBar({
    required this.player,
    required this.scrubPosition,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final Player player;
  final Duration? scrubPosition;
  final void Function(Duration) onScrubStart;
  final void Function(Duration) onScrubUpdate;
  final void Function(Duration) onScrubEnd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (_, posSnap) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (_, durSnap) {
            final pos = scrubPosition ?? posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            final fraction = dur.inMilliseconds > 0
                ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;

            return SizedBox(
              height: 24,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  Duration durFromX(double dx) {
                    final clamped = dx.clamp(0.0, w);
                    final ratio = w == 0 ? 0.0 : clamped / w;
                    return Duration(
                      milliseconds:
                          (dur.inMilliseconds * ratio).round(),
                    );
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) =>
                        onScrubStart(durFromX(d.localPosition.dx)),
                    onHorizontalDragUpdate: (d) =>
                        onScrubUpdate(durFromX(d.localPosition.dx)),
                    onHorizontalDragEnd: (_) => onScrubEnd(pos),
                    onTapDown: (d) {
                      final at = durFromX(d.localPosition.dx);
                      onScrubStart(at);
                      onScrubEnd(at);
                    },
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        // Track
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fraction,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // Scrub head
                        Positioned(
                          left: w * fraction - 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.isLiveMode,
    required this.playing,
    required this.hasMultipleAudioTracks,
    required this.hasSubtitleTracks,
    required this.aspectRatioLabel,
    required this.onTogglePlay,
    required this.onSeekRelative,
    required this.onShowAudioPicker,
    required this.onShowSubtitlePicker,
    required this.onCycleAspect,
    required this.onMore,
  });

  final bool isLiveMode;
  final bool playing;
  final bool hasMultipleAudioTracks;
  final bool hasSubtitleTracks;
  final String aspectRatioLabel;
  final VoidCallback onTogglePlay;
  final void Function(int seconds) onSeekRelative;
  final VoidCallback? onShowAudioPicker;
  final VoidCallback? onShowSubtitlePicker;
  final VoidCallback? onCycleAspect;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (!isLiveMode) ...<Widget>[
          _RoundButton(
            icon: Icons.replay_10,
            label: '−15 s',
            onPressed: () => onSeekRelative(-15),
          ),
          SizedBox(width: DS.space.lg),
        ],
        _RoundButton(
          icon: playing ? Icons.pause : Icons.play_arrow,
          label: playing ? 'Pause' : 'Lecture',
          big: true,
          onPressed: onTogglePlay,
        ),
        if (!isLiveMode) ...<Widget>[
          SizedBox(width: DS.space.lg),
          _RoundButton(
            icon: Icons.forward_30,
            label: '+30 s',
            onPressed: () => onSeekRelative(30),
          ),
        ],
        const Spacer(),
        if (hasMultipleAudioTracks && onShowAudioPicker != null) ...<Widget>[
          _RoundButton(
            icon: Icons.volume_up,
            label: 'Audio',
            onPressed: onShowAudioPicker!,
          ),
          SizedBox(width: DS.space.md),
        ],
        if (hasSubtitleTracks && onShowSubtitlePicker != null) ...<Widget>[
          _RoundButton(
            icon: Icons.closed_caption,
            label: 'Sous-titres',
            onPressed: onShowSubtitlePicker!,
          ),
          SizedBox(width: DS.space.md),
        ],
        if (onCycleAspect != null) ...<Widget>[
          _RoundButton(
            icon: Icons.aspect_ratio,
            label: aspectRatioLabel,
            onPressed: onCycleAspect!,
          ),
          SizedBox(width: DS.space.md),
        ],
        if (onMore != null)
          _RoundButton(
            icon: Icons.more_horiz,
            label: 'Plus',
            onPressed: onMore!,
          ),
      ],
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool big;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHover(bool v) {
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  void _setPress(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 76.0 : 56.0;
    final iconSize = widget.big ? 30.0 : 22.0;
    final active = _hovered;

    final fill = active
        ? AppColors.primaryBlue
        : (widget.big
            ? AppColors.primaryBlue
            : Colors.white.withValues(alpha: 0.12));

    final scale = _pressed ? 0.95 : (_hovered ? 1.10 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPress(true),
        onTapUp: (_) => _setPress(false),
        onTapCancel: () => _setPress(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: DS.focus.animation,
                curve: DS.focus.curve,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: Icon(widget.icon, size: iconSize, color: Colors.white),
              ),
              SizedBox(height: DS.space.xs),
              Text(
                widget.label,
                style: DSText.caption.copyWith(
                  color: active
                      ? Colors.white
                      : DS.colour.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Live-mode top-left overlay block. Mirror of the iOS
/// `IOSPlayerScreen._buildLiveControls` block and the tvOS
/// `VLCLivePlayerViewController` left dense info strip:
///   * `EN DIRECT` red pill
///   * Channel name (26 pt bold)
///   * `Chaîne X / Y` (when caller passes it)
///   * Programme title (18 pt semibold)
///   * `HH:mm → HH:mm` range
///   * Warm-orange progress bar (4 pt, 280 pt wide)
///   * `Suite : <next>` line
///
/// All EPG fields are optional — partial data degrades gracefully so
/// channels without an EPG still get the badge + channel name.
class _LiveOverlay extends StatelessWidget {
  const _LiveOverlay({
    required this.title,
    this.channelLabel,
    this.epgNowTitle,
    this.epgNext,
    this.epgTimeRange,
    this.epgProgress,
  });

  final String title;
  final String? channelLabel;
  final String? epgNowTitle;
  final String? epgNext;
  final String? epgTimeRange;
  final double? epgProgress;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // EN DIRECT pill — matches tvOS liveBadge tint.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD92626),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'EN DIRECT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              shadows: <Shadow>[
                Shadow(color: Colors.black87, blurRadius: 12),
              ],
            ),
          ),
          if (channelLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                channelLabel!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (epgNowTitle != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              epgNowTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: <Shadow>[
                  Shadow(color: Colors.black87, blurRadius: 10),
                ],
              ),
            ),
            if (epgTimeRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  epgTimeRange!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
              ),
            if (epgProgress != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: epgProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      // accentWarm — same orange as tvOS programmeProgressBar.
                      color: const Color(0xFFFF6B5B),
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
            if (epgNext != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Suite : $epgNext',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
