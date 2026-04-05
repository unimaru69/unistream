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
  final void Function()? onVolumeOsd;
  final void Function()? toggleChannelList;
  final void Function(int digit)? onDigitInput;
  final void Function()? onDigitConfirm;

  const PlayerKeyCallbacks({
    required this.playPause,
    required this.seek,
    required this.adjustVolume,
    required this.toggleMute,
    required this.enterFullscreen,
    required this.escape,
    this.zapChannel,
    this.onVolumeOsd,
    this.toggleChannelList,
    this.onDigitInput,
    this.onDigitConfirm,
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
      callbacks.onVolumeOsd?.call();
      return true;
    }
    if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
      callbacks.adjustVolume(-5);
      callbacks.onVolumeOsd?.call();
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
    callbacks.onVolumeOsd?.call();
    return true;
  }
  if (!hasZapping && key == LogicalKeyboardKey.arrowDown) {
    callbacks.adjustVolume(-10);
    callbacks.onVolumeOsd?.call();
    return true;
  }
  if (key == LogicalKeyboardKey.keyL && hasZapping) {
    callbacks.toggleChannelList?.call();
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

  // ── Enter confirms buffered channel number ──
  if (hasZapping && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
    callbacks.onDigitConfirm?.call();
    return true;
  }

  // ── Digit keys 0-9 for direct channel number input ──
  if (hasZapping) {
    final digit = _digitFromKey(key);
    if (digit != null) {
      callbacks.onDigitInput?.call(digit);
      return true;
    }
  }

  return false;
}

/// Returns 0-9 for digit keys (both main row and numpad), null otherwise.
int? _digitFromKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) return 0;
  if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return 1;
  if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return 2;
  if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return 3;
  if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return 4;
  if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return 5;
  if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return 6;
  if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) return 7;
  if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) return 8;
  if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) return 9;
  return null;
}
