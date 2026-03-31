import 'package:flutter/services.dart';

/// Callbacks the keyboard handler can invoke.
class PlayerKeyCallbacks {
  final void Function() playPause;
  final void Function(Duration delta) seek;
  final void Function(double delta) adjustVolume;
  final void Function() toggleMute;
  final void Function() enterFullscreen;
  final void Function() escape;
  final void Function(int delta)? zapChannel;

  const PlayerKeyCallbacks({
    required this.playPause,
    required this.seek,
    required this.adjustVolume,
    required this.toggleMute,
    required this.enterFullscreen,
    required this.escape,
    this.zapChannel,
  });
}

/// Pure function that maps keyboard events to player actions.
///
/// [isLiveMode] — true for live streams (seeking disabled).
/// [hasZapping] — true when channel zapping is available (arrows = zap).
/// [isRouteActive] — true when the player route is topmost.
bool handlePlayerKeyEvent(
  KeyEvent event, {
  required PlayerKeyCallbacks callbacks,
  required bool isLiveMode,
  required bool hasZapping,
  required bool isRouteActive,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
  final key = event.logicalKey;

  // When not the active route, only Escape and F pass through
  if (!isRouteActive) {
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyF) {
      callbacks.escape();
      return true;
    }
    return false;
  }

  // ── Repeat events (held keys) ──
  if (event is KeyRepeatEvent) {
    if (!isLiveMode && key == LogicalKeyboardKey.arrowLeft) {
      callbacks.seek(const Duration(seconds: -10));
      return true;
    }
    if (!isLiveMode && key == LogicalKeyboardKey.arrowRight) {
      callbacks.seek(const Duration(seconds: 10));
      return true;
    }
    if (hasZapping && key == LogicalKeyboardKey.arrowUp) {
      callbacks.zapChannel?.call(-1);
      return true;
    }
    if (hasZapping && key == LogicalKeyboardKey.arrowDown) {
      callbacks.zapChannel?.call(1);
      return true;
    }
    if (!hasZapping && key == LogicalKeyboardKey.arrowUp) {
      callbacks.adjustVolume(5);
      return true;
    }
    if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
      callbacks.adjustVolume(-5);
      return true;
    }
    return false;
  }

  // ── Single press events ──
  if (key == LogicalKeyboardKey.space) {
    callbacks.playPause();
    return true;
  }
  if (!isLiveMode && key == LogicalKeyboardKey.arrowLeft) {
    callbacks.seek(const Duration(seconds: -10));
    return true;
  }
  if (!isLiveMode && key == LogicalKeyboardKey.arrowRight) {
    callbacks.seek(const Duration(seconds: 10));
    return true;
  }
  if (key == LogicalKeyboardKey.keyF) {
    callbacks.enterFullscreen();
    return true;
  }
  if (key == LogicalKeyboardKey.keyM) {
    callbacks.toggleMute();
    return true;
  }
  if (hasZapping && key == LogicalKeyboardKey.arrowUp) {
    callbacks.zapChannel?.call(-1);
    return true;
  }
  if (hasZapping && key == LogicalKeyboardKey.arrowDown) {
    callbacks.zapChannel?.call(1);
    return true;
  }
  if (!hasZapping && key == LogicalKeyboardKey.arrowUp) {
    callbacks.adjustVolume(10);
    return true;
  }
  if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
    callbacks.adjustVolume(-10);
    return true;
  }
  if (key == LogicalKeyboardKey.escape) {
    callbacks.escape();
    return true;
  }
  if (isLiveMode) {
    if (key == LogicalKeyboardKey.keyP) {
      callbacks.zapChannel?.call(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.keyN) {
      callbacks.zapChannel?.call(1);
      return true;
    }
  }
  return false;
}
